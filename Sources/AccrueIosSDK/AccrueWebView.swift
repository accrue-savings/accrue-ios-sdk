#if canImport(UIKit)

import SwiftUI
import WebKit
import UIKit
import Foundation
import SafariServices
 
public class WebViewModel: ObservableObject {
    @Published public var link: String
    @Published public var didFinishLoading: Bool = true

    public init (link: String) {
        self.link = link
    }
}

extension WebViewModel: Equatable {
    public static func == (lhs: WebViewModel, rhs: WebViewModel) -> Bool {
        return lhs.link == rhs.link && lhs.didFinishLoading == rhs.didFinishLoading
    }
}


@available(iOS 13.0, macOS 10.15, *)
public struct AccrueWebView: UIViewRepresentable {
    public let url: URL
    public var contextData: AccrueContextData?
    public var onAction: ((String) -> Void)?
    
    public init(url: URL, contextData: AccrueContextData? = nil, onAction: ((String) -> Void)? = nil) {
        self.url = url
        self.contextData = contextData
        self.onAction = onAction
    }
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var parent: AccrueWebView
        
        public init(parent: AccrueWebView) {
            self.parent = parent
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == AccrueWebEvents.EventHandlerName, let userData = message.body as? String {
                parent.onAction?(userData)
            }
        }
        // Intercept navigation actions for internal vs external URLs
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Only handle navigation if it was triggered by a link (not by an iframe load, script, etc.)
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
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
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if shouldOpenExternally(url: url) {
                    print("Pop Up triggered, openning In-App Browser")
                    // Open the link in an in-app browser (SFSafariViewController)
                    openInAppBrowser(url: url)
                    return nil
                }
            }
            return nil
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
            guard let viewController = UIApplication.shared.windows.first?.rootViewController else { return }
            let safariVC = SFSafariViewController(url: url)
            viewController.present(safariVC, animated: true, completion: nil)
        }
      
        
        
    }
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Set the navigation delegate
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        if #available(iOS 16.4, *) {
            webView.isInspectable = true // Safe to use isInspectable here
        }
        // Add the script message handler
        let userContentController = webView.configuration.userContentController
        userContentController.add(context.coordinator, name: AccrueWebEvents.EventHandlerName)
        
        
        // Inject JavaScript to set context data
        insertContextData(userController: userContentController)
        
        return webView
    }
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        
        
        if url != uiView.url {
            uiView.load(request)
        }
        print("Updating context")
        // Refresh context data
        refreshContextData(webView: uiView)
        if(contextData?.actions.action == "AccrueTabPressed"){
            sendCustomEventGoToHomeScreen(webView: uiView)
        }
    }
    
    
    
    private func refreshContextData(webView: WKWebView) -> Void {
        if let contextData = contextData {
            
            let contextDataScript = generateContextDataScript(contextData: contextData)
            webView.evaluateJavaScript(contextDataScript){ result, error in
                if let error = error {
                    print("JavaScript injection error: \(error.localizedDescription)")
                               if let nsError = error as? NSError {
                                   print("Error Domain: \(nsError.domain)")
                                   print("Error Code: \(nsError.code)")
                                   if let userInfo = nsError.userInfo as? [String: Any] {
                                       print("User Info: \(userInfo)")
                                   }
                               }
                } else {
                    print("JavaScript executed successfully: \(String(describing: result))")
                }
            }
        }
    }
    
    private func insertContextData(userController: WKUserContentController) -> Void {
        if let contextData = contextData {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            print(contextDataScript)
            let userScript = WKUserScript(source: contextDataScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userController.addUserScript(userScript)
        }
    }
    // Generate JavaScript for Context Data
    private func generateContextDataScript(contextData: AccrueContextData) -> String {
        let userData = contextData.userData
        let settingsData = contextData.settingsData
        let deviceContextData = AccrueDeviceContextData()
        return """
          (function() {
                window["\(AccrueWebEvents.EventHandlerName)"] = {
                    "contextData": {
                        "userData": {
                            "referenceId": \(userData.referenceId.map { "\"\($0)\"" } ?? "null"),
                            "email": \(userData.email.map { "\"\($0)\"" } ?? "null"),
                            "phoneNumber": \(userData.phoneNumber.map { "\"\($0)\"" } ?? "null")
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
          })();
          """
    }
    
    
    
    public func sendCustomEventGoToHomeScreen(webView: WKWebView) {
        print("Calling sendCustomEventGoToHomeScreen...")
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
        
        injectFunctionCall(
            webView: webView,
            functionIdentifier: eventName,
            functionArguments: arguments
        )
    }

    
    private func injectFunctionCall(
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
        
       print("Script: \(script) ")
        webView.evaluateJavaScript(script){ result, error in
            if let error = error {
                print("JavaScript injection error: \(error.localizedDescription)")
            } else {
                print("JavaScript executed successfully: \(String(describing: result))")
            }
        }
      
    }
    
    
}
#endif
