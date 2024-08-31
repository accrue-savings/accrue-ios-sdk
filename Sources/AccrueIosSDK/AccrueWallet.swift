import SwiftUI

public struct AccrueWallet: View {
    public let merchantId: String
    public let redirectionToken: String?
    public var onAction: ((String) -> Void)?
    public var contextData: AccrueContextData?
    
    
    public init(merchantId: String, redirectionToken: String, contextData: AccrueContextData? = nil, onAction: ((String) -> Void)? = nil) {
      self.merchantId = merchantId
      self.redirectionToken = redirectionToken
      self.contextData = contextData
      self.onAction = onAction
    }
    
    @available(macOS 10.15, *)
    public var body: some View {
        #if os(iOS)
        if let url = buildURL() {
            WebView(url: url, contextData: contextData, onSignIn: onSignIn)
        } else {
            Text("Invalid URL")
        }
        #else
        Text("Platform not supported")
        #endif
    }
    
    private func buildURL() -> URL? {
        var urlComponents = URLComponents(string: AppConstants.apiBaseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "merchantId", value: merchantId)
        ]
        
        if let redirectionToken = redirectionToken {
            urlComponents?.queryItems?.append(URLQueryItem(name: "redirectionToken", value: redirectionToken))
        }
        
        return urlComponents?.url
    }
}
