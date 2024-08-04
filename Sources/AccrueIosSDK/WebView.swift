import SwiftUI
import WebKit

import Foundation

import SwiftUI

public struct ContextData {
    let referenceId: String
    let email: String
    let phoneNumber: String
}

#if os(iOS)
public struct WebView: UIViewRepresentable {
    let url: URL
    var contextData: ContextData?
    var onSignIn: ((String) -> Void)?
      
    class Coordinator: NSObject, WKScriptMessageHandler {
      var parent: WebView
          
      init(parent: WebView) {
          self.parent = parent
      }
          
      func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
          print("Being called")
          print(message.name)
          if message.name == AccrueWebEvents.EventHandlerName, let userData = message.body as? String {
              parent.onSignIn?(userData)
          }
      }
    }
    func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
    }
    @available(iOS 13.0, *)
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Add the script message handler
        let userContentController = webView.configuration.userContentController
        userContentController.add(context.coordinator, name: AccrueWebEvents.EventHandlerName)

       
        // Inject JavaScript to set context data
        if let contextData = contextData {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            print(contextDataScript)
            let userScript = WKUserScript(source: contextDataScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }
       
        return webView
    }
    @available(iOS 13.0, *)
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
      
        uiView.load(request)
    }
    // Generate JavaScript for Context Data
    private func generateContextDataScript(contextData: ContextData) -> String {
        return """
              window["\(AccrueWebEvents.EventHandlerName)"] = {
                    "contextData": {
                        "referenceId": "\(contextData.referenceId)",
                        "email": "\(contextData.email)",
                        "phoneNumber": "\(contextData.phoneNumber)"
                    }
              };
              """
    }
}
#endif
