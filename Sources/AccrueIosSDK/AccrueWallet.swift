import SwiftUI

@available(macOS 10.15, *)
public struct AccrueWallet: View {
    public let merchantId: String
    public let redirectionToken: String?
    public let isSandbox: Bool
    public let url: String?
    public var onAction: ((String) -> Void)?
    @State private var isLoading: Bool = false

    @ObservedObject var contextData: AccrueContextData
#if os(iOS)
    private var WebViewComponent: AccrueWebView {
        let fallbackUrl = URL(string: AppConstants.productionUrl)!
        let url = buildURL(isSandbox: isSandbox, url: url) ?? fallbackUrl
        
        return AccrueWebView(url: url, contextData: contextData, onAction: onAction, isLoading: $isLoading)
    }
#endif
 
    public init(merchantId: String, redirectionToken: String?,isSandbox: Bool,url: String? = nil, contextData: AccrueContextData = AccrueContextData(), onAction: ((String) -> Void)? = nil) {
        self.merchantId = merchantId
        self.redirectionToken = redirectionToken
        self.contextData = contextData
        self.isSandbox = isSandbox
        self.url = url
        self.onAction = onAction
    }
    
    public var body: some View {
#if os(iOS)
        WebViewComponent
        if isLoading {
            VStack {
                if #available(iOS 14.0, *) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                } else {
                    ProgressView()
                    .scaleEffect(1.5)
                }
                Text("Loading...")
                .font(.headline)
                .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.8))
            .edgesIgnoringSafeArea(.all)
        }
#endif
    }
    
    public func handleEvent(event: String) {
        contextData.setAction(action: event)
    }
       
    
    private func buildURL(isSandbox:Bool, url:String?) -> URL? {
        let apiBaseUrl: String
        
        if isSandbox {
            apiBaseUrl = AppConstants.sandboxUrl
        } else if let validUrl = url {
            apiBaseUrl = validUrl
        } else {
            apiBaseUrl = AppConstants.productionUrl
        }
        var urlComponents = URLComponents(string: apiBaseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "merchantId", value: merchantId)
        ]
        
        if let redirectionToken = redirectionToken {
            urlComponents?.queryItems?.append(URLQueryItem(name: "redirectionToken", value: redirectionToken))
        }
        
        return urlComponents?.url
    }
        
}
