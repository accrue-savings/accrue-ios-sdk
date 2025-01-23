import SwiftUI

@available(macOS 10.15, *)
public struct AccrueWallet: View {
    public let merchantId: String
    public let redirectionToken: String?
    public let isSandbox: Bool
    public let url: String?
    public var onAction: ((String) -> Void)?
    @ObservedObject var contextData: AccrueContextData
    public var externalHandleEvent: ((String) -> Void)? // Closure to expose handleEvent
#if os(iOS)
    @State private var webViewCoordinator: WebView.Coordinator? // Store the Coordinator reference
#endif
    
    
    public init(merchantId: String, redirectionToken: String?,isSandbox: Bool,url: String? = nil, contextData: AccrueContextData = AccrueContextData(), onAction: ((String) -> Void)? = nil, externalHandleEvent: ((String) -> Void)? = nil) {
        self.merchantId = merchantId
        self.redirectionToken = redirectionToken
        self.contextData = contextData
        self.isSandbox = isSandbox
        self.url = url
        self.onAction = onAction
        self.externalHandleEvent = externalHandleEvent
    }
    
    public var body: some View {
#if os(iOS)
        if let url = buildURL(isSandbox: isSandbox, url: url) {
            WebView(url: url, contextData: contextData, onAction: onAction, onCoordinatorCreated: { coordinator in
                self.webViewCoordinator = coordinator // Capture the Coordinator
            }).onAppear {
                // Expose handleEvent logic to the parent
                externalHandleEvent = self.handleEvent
            }
        } else {
            Text("Invalid URL")
        }
#else
        Text("Platform not supported")
#endif
    }
    
    private func handleEvent(event: String) {
#if os(iOS)
        if event == "AccrueTabPressed" {
            self.webViewCoordinator?.sendCustomEventGoToHomeScreen()
        }
#endif
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
