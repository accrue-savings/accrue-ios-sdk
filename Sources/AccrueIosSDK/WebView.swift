#if canImport(UIKit)

import SwiftUI
import WebKit
import UIKit
import Foundation


@available(macOS 10.15, *)
public struct WebView: UIViewRepresentable {
    public let url: URL
    public var contextData: AccrueContextData?
    public var onAction: ((String) -> Void)?
      
    
    public init(url: URL, contextData: AccrueContextData? = nil, onAction: ((String) -> Void)? = nil) {
           self.url = url
           self.contextData = contextData
           self.onAction = onAction
   }
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        
        public init(parent: WebView) {
            self.parent = parent
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
          if message.name == AccrueWebEvents.EventHandlerName, let userData = message.body as? String {
              parent.onAction?(userData)
          }
        }
        // WKNavigationDelegate method to intercept navigation actions
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
           if let url = navigationAction.request.url {
               // Check if the URL is external
               if url.host != parent.url.host {
                   // Open the , URL in the external browser
                   UIApplication.shared.open(url, options: [:], completionHandler: nil)
                   decisionHandler(.cancel) // Cancel the navigation in the webview
                   return
               }
           }
           // Allow navigation for internal links
           decisionHandler(.allow)
        }
    }
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    @available(iOS 13.0, *)
    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Set the navigation delegate
        webView.navigationDelegate = context.coordinator
        // Add the script message handler
        let userContentController = webView.configuration.userContentController
        userContentController.add(context.coordinator, name: AccrueWebEvents.EventHandlerName)
        
        
        // Inject JavaScript to set context data
        insertContextData(userController: userContentController)
        
        return webView
    }
    @available(iOS 13.0, *)
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        
      
        if url != uiView.url {
            uiView.load(request)
        }
        
        // Refresh context data
        refreshContextData(webView: uiView)
    }
    
    private func refreshContextData(webView: WKWebView) -> Void {
        if let contextData = contextData {
            
            let contextDataScript = generateContextDataScript(contextData: contextData)
            webView.evaluateJavaScript(contextDataScript)
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
}
#endif
