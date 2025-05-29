#if canImport(UIKit)

    import SwiftUI
    import WebKit
    import UIKit
    import Foundation
    import SafariServices

    @available(iOS 13.0, macOS 10.15, *)
    public struct AccrueWebView: UIViewRepresentable {
        public let url: URL
        public var contextData: AccrueContextData?
        public var onAction: ((String) -> Void)?
        @Binding var isLoading: Bool

        // Add a static dictionary to track WebView instances
        private static var webViewInstances: [URL: WKWebView] = [:]

        public init(
            url: URL, contextData: AccrueContextData? = nil, onAction: ((String) -> Void)? = nil,
            isLoading: Binding<Bool>
        ) {
            self.url = url
            self.contextData = contextData
            self.onAction = onAction
            self._isLoading = isLoading
        }
        public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate,
            WKUIDelegate
        {

            var parent: AccrueWebView
            weak var webView: WKWebView?  // 🆕 keep a reference

            public init(parent: AccrueWebView) {
                self.parent = parent
            }

            public func userContentController(
                _ userContentController: WKUserContentController,
                didReceive message: WKScriptMessage
            ) {
                print("AccrueWebView: Received message: \(message.body)")
                guard message.name == AccrueWebEvents.EventHandlerName,
                    let body = message.body as? String
                else { return }

                if let data = body.data(using: .utf8),
                    let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let type = envelope["key"] as? String
                {

                    switch type {
                    case AccrueWebEvents.AppleWalletProvisioningRequested:
                        // 🔑  use the saved WKWebView (fallback to message.webView when available)
                        guard let wv = self.webView ?? message.webView else {
                            parent.onAction?(body)
                            return
                        }
                        print("AccrueWebView: Starting in-app provisioning...")
                        AppleWalletPushProvisioningManager.shared.start(
                            from: wv,
                            with: envelope["data"] as? [String: String] ?? [:]
                        )

                    case AccrueWebEvents.AppleWalletProvisioningSignResponse:
                        print("AccrueWebView: Handling backend response for in-app provisioning...")
                        if let raw = envelope["data"] as? String {
                            AppleWalletPushProvisioningManager.shared.handleBackendResponse(
                                rawJSON: raw)
                        }

                    default:
                        parent.onAction?(body)
                    }
                } else {
                    parent.onAction?(body)
                }
            }
            // Intercept navigation actions for internal vs external URLs
            public func webView(
                _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                print("AccrueWebView: Deciding policy for navigation action: \(navigationAction)")
                print("AccrueWebView: Navigation type: \(navigationAction.navigationType)")
                print("AccrueWebView: Request: \(navigationAction.request)")
                print("AccrueWebView: Request URL: \(navigationAction.request.url)")
                print("AccrueWebView: Request URL host: \(navigationAction.request.url?.host)")
                print("AccrueWebView: Request URL scheme: \(navigationAction.request.url?.scheme)")
                print("AccrueWebView: Request URL path: \(navigationAction.request.url?.path)")
                print("AccrueWebView: Request URL query: \(navigationAction.request.url?.query)")
                // Only handle navigation if it was triggered by a link (not by an iframe load, script, etc.)
                if navigationAction.navigationType == .linkActivated {
                    if let url = navigationAction.request.url {
                        if isDeepLink(url) {
                            openSystemDeepLink(url: url)
                            return
                        }
                        // Check if the URL is external (i.e., different from the original host)
                        if shouldOpenExternally(url: url) {
                            print("Link clicked, openning In-App Browser")
                            openInAppBrowser(url: url)
                            decisionHandler(.cancel)
                            return
                        }
                    }
                }
                decisionHandler(.allow)
            }

            // Handle popups or window.open calls in the web view
            public func webView(
                _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
            ) -> WKWebView? {
                if let url = navigationAction.request.url {
                    if isDeepLink(url) {
                        openSystemDeepLink(url: url)
                        return nil
                    }
                    if shouldOpenExternally(url: url) {
                        print("Pop Up triggered, openning In-App Browser")
                        // Open the link in an in-app browser (SFSafariViewController)
                        openInAppBrowser(url: url)
                        return nil
                    }
                }
                return nil
            }

            public func webView(
                _ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!
            ) {
                DispatchQueue.main.async {
                    self.parent.isLoading = true  // ✅ Safe UI update
                }
            }

            public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
            }

            public func webView(
                _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
            ) {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
            }

            // Helper function to determine if the URL should be opened externally
            private func shouldOpenExternally(url: URL) -> Bool {
                // Only open external URLs (i.e., URLs not matching the parent WebView's host)
                if let host = url.host {
                    return host != parent.url.host
                }

                return false
            }
            // Open the URL in an in-app browser (SFSafariViewController)
            private func openInAppBrowser(url: URL) {
                guard let viewController = UIApplication.shared.windows.first?.rootViewController
                else { return }
                let safariVC = SFSafariViewController(url: url)
                viewController.present(safariVC, animated: true, completion: nil)
            }

            private func isDeepLink(_ url: URL) -> Bool {
                guard let scheme = url.scheme?.lowercased() else {
                    return false
                }
                // Allow wallet:// scheme along with other standard schemes
                return !["http", "https", "mailto", "tel", "sms", "ftp", "wallet"].contains(scheme)
            }

            private func openSystemDeepLink(url: URL) {
                if UIApplication.shared.canOpenURL(url) {
                    print("Opening deep link: \(url)")
                    UIApplication.shared.open(url, options: [:]) { success in
                        if !success {
                            print("Failed to open deep link: \(url)")
                        }
                    }
                } else {
                    print("No app can handle deep link: \(url)")
                }
            }
        }
        public func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }
        public func makeUIView(context: Context) -> WKWebView {
            // Check if we already have a WebView instance for this URL
            if let existingWebView = Self.webViewInstances[url] {
                return existingWebView
            }

            // Configure the website data store
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()

            // Create WebView with the configuration
            let webView = WKWebView(frame: .zero, configuration: configuration)

            // Set the navigation delegate
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator

            // Disable zoom and pinch effect
            webView.isMultipleTouchEnabled = false
            webView.scrollView.pinchGestureRecognizer?.isEnabled = false
            webView.scrollView.minimumZoomScale = 1.0
            webView.scrollView.maximumZoomScale = 1.0

            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }

            // Add the script message handler
            let userContentController = webView.configuration.userContentController
            userContentController.add(context.coordinator, name: AccrueWebEvents.EventHandlerName)

            // Inject JavaScript to set context data
            insertContextData(userController: userContentController)

            // Store the WebView instance
            Self.webViewInstances[url] = webView

            context.coordinator.webView = webView  // 🆕 let the coordinator remember the instance

            return webView
        }
        public func updateUIView(_ uiView: WKWebView, context: Context) {
            // Only load the URL if it's different from the current one
            if url != uiView.url {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                uiView.load(request)
            }

            // Refresh context data
            refreshContextData(webView: uiView)
            if let action = contextData?.actions.action {
                sendEventsToWebView(webView: uiView, action: action)
            }
        }

        private func sendEventsToWebView(webView: WKWebView, action: String?) {
            if action == "AccrueTabPressed" {
                sendCustomEventGoToHomeScreen(webView: webView)
            } else {
                print("Event not supported: \(action)")
            }
        }

        private func refreshContextData(webView: WKWebView) {
            if let contextData = contextData {
                let contextDataScript = generateContextDataScript(contextData: contextData)
                print("Refreshing contextData: \(contextDataScript)")
                webView.evaluateJavaScript(contextDataScript)
            }
        }

        private func insertContextData(userController: WKUserContentController) {
            if let contextData = contextData {
                let contextDataScript = generateContextDataScript(contextData: contextData)
                print("Inserting contextData: \(contextDataScript)")
                let userScript = WKUserScript(
                    source: contextDataScript, injectionTime: .atDocumentStart,
                    forMainFrameOnly: false)
                userController.addUserScript(userScript)
            }
        }
        // Generate JavaScript for Context Data
        private func generateContextDataScript(contextData: AccrueContextData) -> String {
            let userData = contextData.userData
            let settingsData = contextData.settingsData
            let deviceContextData = AccrueDeviceContextData()
            let additionalDataJSON = UserDataHelper.parseDictionaryToJSONString(
                contextData.userData.additionalData)
            return """
                (function() {
                      window["\(AccrueWebEvents.EventHandlerName)"] = {
                          "contextData": {
                              "userData": {
                                  "referenceId": \(userData.referenceId.map { "\"\($0)\"" } ?? "null"),
                                  "email": \(userData.email.map { "\"\($0)\"" } ?? "null"),
                                  "phoneNumber": \(userData.phoneNumber.map { "\"\($0)\"" } ?? "null"),
                                  "additionalData": \(additionalDataJSON)
                              },
                              "settingsData": {
                                  "shouldInheritAuthentication": \(settingsData.shouldInheritAuthentication)
                              },
                              "deviceData": {
                                  "sdk": "\(deviceContextData.sdk)",
                                  "sdkVersion": "\(deviceContextData.sdkVersion ?? "null")",
                                  "brand": "\(deviceContextData.brand ?? "null")",
                                  "deviceName": "\(deviceContextData.deviceName ?? "null")",
                                  "deviceType": "\(deviceContextData.deviceType ?? "")",
                                  "deviceYearClass": "\(deviceContextData.deviceYearClass ?? 0)",
                                  "isDevice": \(deviceContextData.isDevice),
                                  "manufacturer": "\(deviceContextData.manufacturer ?? "null")",
                                  "modelName": "\(deviceContextData.modelName ?? "null")",
                                  "osBuildId": "\(deviceContextData.osBuildId ?? "null")",
                                  "osInternalBuildId": "\(deviceContextData.osInternalBuildId ?? "null")",
                                  "osName": "\(deviceContextData.osName ?? "null")",
                                  "osVersion": "\(deviceContextData.osVersion ?? "null")",
                                  "modelId": "\(deviceContextData.modelId ?? "null")"
                              }
                          }
                      };
                      // Notify the web page that contextData has been updated
                      var event = new CustomEvent("\(AccrueWebEvents.AccrueWalletContextChangedEventKey)", {
                        detail: window["\(AccrueWebEvents.EventHandlerName)"].contextData
                      });
                      window.dispatchEvent(event);
                })();
                """
        }

        public func sendCustomEventGoToHomeScreen(webView: WKWebView) {
            sendCustomEvent(
                webView: webView,
                eventName: "__GO_TO_HOME_SCREEN",
                arguments: ""
            )
        }

        public func sendCustomEvent(
            webView: WKWebView,
            eventName: String,
            arguments: String = ""
        ) {

            injectEvent(
                webView: webView,
                functionIdentifier: eventName,
                functionArguments: arguments
            )
        }

        private func injectEvent(
            webView: WKWebView,
            functionIdentifier: String,
            functionArguments: String
        ) {

            let script = """
                (function() {
                    if (typeof window !== "undefined" && typeof window.\(functionIdentifier) === "function") {
                        window.\(functionIdentifier)(\(functionArguments));
                    }
                    return "Script injected successfully";
                })();
                """
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("JavaScript injection error: \(error.localizedDescription)")
                } else {
                    print("JavaScript executed successfully: \(String(describing: result))")

                }
                contextData?.clearAction()
            }

        }

        public static func clearWebsiteData() {
            let dataTypes = Set([WKWebsiteDataTypeLocalStorage])
            let date = Date(timeIntervalSince1970: 0)
            WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: date) {
                print("Website data cleared")
            }
        }

        // Add cleanup method
        public static func cleanup() {
            // Remove all WebView instances
            webViewInstances.removeAll()

            // Clear website data
            clearWebsiteData()
        }
        // Trigger a context data refresh
        public func triggerContextDataRefresh() {
            let instance = Self.webViewInstances[url]
            if let webView = instance {
                refreshContextData(webView: webView)
            } else {
                print("AccrueWebView: No web view found")
            }
        }
    }
#endif
