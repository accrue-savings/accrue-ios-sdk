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
            url: URL,
            contextData: AccrueContextData? = nil,
            onAction: ((String) -> Void)? = nil,
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
                // Use WebViewCommunication to handle incoming events
                _ = WebViewCommunication.handleIncomingEvent(
                    message,
                    webView: self.webView,
                    onAction: parent.onAction
                )
            }

            // Intercept navigation actions for internal vs external URLs
            public func webView(
                _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                let statementDownloader = StatementDownloader()

                // IF scheme is wallet://, open the link in an in-app browser (SFSafariViewController)
                if isWalletDeepLink(url: navigationAction.request.url!) {
                    openSystemDeepLink(url: navigationAction.request.url!)
                    decisionHandler(.cancel)
                    return
                }

                // For statement downloads, handle to iOS URLSessionDownloadTask
                if isStatementDownloadUrl(url: navigationAction.request.url!) {
                    statementDownloader.downloadStatement(url: navigationAction.request.url!)
                    decisionHandler(.cancel)
                    return
                }

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

            // MARK: - Content process termination
            public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
                print("❌ WebView content process terminated")
                hardReload(webView)
            }

            private func hardReload(_ webView: WKWebView) {
                DispatchQueue.main.async {
                    self.parent.isLoading = true
                    if let current = webView.url {
                        webView.load(URLRequest(url: current))
                    } else {
                        webView.load(URLRequest(url: self.parent.url))
                    }
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
            private func isWalletDeepLink(url: URL) -> Bool {
                return url.scheme == "wallet"
            }
            private func isStatementDownloadUrl(url: URL) -> Bool {
                return url.absoluteString.contains("/statements/")
                    && url.absoluteString.contains("/download")
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
            userContentController.add(
                context.coordinator, name: AccrueEvents.EventHandlerName)

            // Inject JavaScript to set context data using ContextDataGenerator
            if let contextData = contextData {
                ContextDataGenerator.injectContextData(
                    into: userContentController, contextData: contextData)
            }

            // Store the WebView instance
            Self.webViewInstances[url] = webView

            context.coordinator.webView = webView  // 🆕 let the coordinator remember the instance

            return webView
        }

        public func updateUIView(_ uiView: WKWebView, context: Context) {
            // Only load the URL if it's different from the current one
            if url != uiView.url {
                var request = URLRequest(url: url)
                // Respect server cache headers (Cloudflare) instead of forcing our own
                request.cachePolicy = .useProtocolCachePolicy
                uiView.load(request)
            }

            // Refresh context data using ContextDataGenerator (but not actions)
            if let contextData = contextData {
                ContextDataGenerator.refreshContextData(in: uiView, contextData: contextData)
                // Remove the handleContextDataAction call from here since we handle events directly now
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

        // Static method to send events directly using stored webview instances
        public static func sendEventDirectly(to url: URL, event: String) {
            print("📤 AccrueWebView: Sending event '\(event)' to webview")

            guard let webView = webViewInstances[url] else {
                print("❌ AccrueWebView: No webview found for URL: \(url)")
                return
            }

            // Handle different event types directly
            switch event {
            case AccrueEvents.OutgoingToWebView.ExternalEvents.TabPressed:
                WebViewCommunication.callCustomFunction(
                    to: webView,
                    functionName: AccrueEvents.OutgoingToWebView.Functions.GoToHomeScreen
                )
                print("✅ AccrueWebView: TabPressed event sent successfully")
            default:
                print("❌ AccrueWebView: Event not supported: \(event)")
            }
        }

        // Trigger a context data refresh
        public func triggerContextDataRefresh() {
            let instance = Self.webViewInstances[url]
            if let webView = instance, let contextData = contextData {
                ContextDataGenerator.refreshContextData(in: webView, contextData: contextData)
            } else {
                print("AccrueWebView: No web view found")
            }
        }
    }
#endif
