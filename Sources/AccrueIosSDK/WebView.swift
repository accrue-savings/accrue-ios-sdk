import SwiftUI
import WebKit

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
    public class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebView
        
        public init(parent: WebView) {
            self.parent = parent
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
          if message.name == AccrueWebEvents.EventHandlerName, let userData = message.body as? String {
              parent.onAction?(userData)
          }
        }
    }
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    @available(iOS 13.0, *)
    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
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
            print("Updating view...")
        }else {
            print("URL unchanged, updating context data...")
        }
       
        
        // Remove all existing user scripts
        uiView.configuration.userContentController.removeAllUserScripts()
        
        // Inject the updated context data
        if let contextData = contextData {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            uiView.evaluateJavaScript(contextDataScript)
        }
    }
    
    private func insertContextData(userController: WKUserContentController, shouldForceUpdate: Bool = false) -> Void {
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
        window["\(AccrueWebEvents.EventHandlerName)"] = {
            "contextData": {
                "userData": {
                    "referenceId": \(userData.referenceId.map { "\"\($0)\"" } ?? "null"),
                    "email": \(userData.email.map { "\"\($0)\"" } ?? "null"),
                    "phoneNumber": \(userData.phoneNumber.map { "\"\($0)\"" } ?? "null")
                },
                "settingsData": {
                    "disableLogout": \(settingsData.disableLogout),
                    "loginRequiresReferenceId": \(settingsData.loginRequiresReferenceId),
                    "skipPhoneInputScreen": \(settingsData.skipPhoneInputScreen)
                }
            }
        };
        """
    }
}

