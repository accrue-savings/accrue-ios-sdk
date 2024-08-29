import SwiftUI

public struct AccrueWallet: View {
    public let merchantId: String
    public let redirectionToken: String
    public var onAction: ((String) -> Void)?
    public var contextData: ContextData?
    
    
    public init(merchantId: String, redirectionToken: String, contextData: ContextData? = nil, onAction: ((String) -> Void)? = nil) {
      self.merchantId = merchantId
      self.redirectionToken = redirectionToken
      self.contextData = contextData
      self.onAction = onAction
    }
    
    @available(macOS 10.15, *)
    public var body: some View {
        #if os(iOS)
        if let url = URL(string: "\(AppConstants.apiBaseUrl)?merchantId=\(merchantId)&redirectionToken=\(redirectionToken)") {
            WebView(url: url,contextData: contextData, onSignIn: onSignIn )
        } else {
            Text("Invalid URL")
        }
        #else
            Text("Platform not supported")
        #endif
    }
}
