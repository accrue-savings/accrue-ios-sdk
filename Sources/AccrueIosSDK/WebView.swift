import SwiftUI
import WebKit

import Foundation

public struct AccrueContextData {
    public let userData: AccrueUserData?
    public let settingsData: AccrueSettingsData
    
    public init(
        userData: AccrueUserData? = nil,
        settingsData: AccrueSettingsData = AccrueSettingsData()
    ) {
        self.userData = userData
        self.settingsData = settingsData
    }
}

public struct AccrueUserData {
    public let referenceId: String?
    public let email: String?
    public let phoneNumber: String?
    
    public init(
        referenceId: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil
    ) {
        self.referenceId = referenceId
        self.email = email
        self.phoneNumber = phoneNumber
    }
}

public struct AccrueSettingsData {
    public let disableLogout: Bool
    public let loginRequiresReferenceId: Bool
    public let skipPhoneInputScreen: Bool
    
    public init(
        disableLogout: Bool = false,
        loginRequiresReferenceId: Bool = false,
        skipPhoneInputScreen: Bool = false
    ) {
        self.disableLogout = disableLogout
        self.loginRequiresReferenceId = loginRequiresReferenceId
        self.skipPhoneInputScreen = skipPhoneInputScreen
    }
}

#if os(iOS)
public struct WebView: UIViewRepresentable {
    public let url: URL
    public var contextData: ContextData?
    public var onAction: ((String) -> Void)?
      
    
    public init(url: URL, contextData: ContextData? = nil, onAction: ((String) -> Void)? = nil) {
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
        if let contextData = contextData {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            print(contextDataScript)
            let userScript = WKUserScript(source: contextDataScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }
        
        return webView
    }
    @available(iOS 13.0, *)
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        
        uiView.load(request)
    }
    // Generate JavaScript for Context Data
    private func generateContextDataScript(contextData: AccrueContextData) -> String {
        let userData = contextData.userData
        let settingsData = contextData.settingsData
        
        return """
        window["\(AccrueWebEvents.EventHandlerName)"] = {
            "contextData": {
                "userData": {
                    "referenceId": \(userData?.referenceId.map { "\"\($0)\"" } ?? "null"),
                    "email": \(userData?.email.map { "\"\($0)\"" } ?? "null"),
                    "phoneNumber": \(userData?.phoneNumber.map { "\"\($0)\"" } ?? "null")
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
#endif
