import SwiftUI

@available(macOS 10.15, *)
public struct AccrueWallet: View {
    public let merchantId: String
    public let redirectionToken: String?
    public let isSandbox: Bool
    public let url: String?
    public var onAction: ((String) -> Void)?
    public var shouldShowLoader: Bool = true
    @State private var isLoading: Bool = false

    @ObservedObject public var contextData: AccrueContextData
    #if os(iOS)
        private var WebViewComponent: AccrueWebView {
            let fallbackUrl = URL(string: AppConstants.productionUrl)!
            let url = buildURL(isSandbox: isSandbox, url: url) ?? fallbackUrl

            return AccrueWebView(
                url: url, contextData: contextData, onAction: onAction, isLoading: $isLoading)
        }
    #endif

    public init(
        merchantId: String, redirectionToken: String?, isSandbox: Bool, url: String? = nil,
        contextData: AccrueContextData = AccrueContextData(), onAction: ((String) -> Void)? = nil,
        shouldShowLoader: Bool = true
    ) {
        self.merchantId = merchantId
        self.redirectionToken = redirectionToken
        self.contextData = contextData
        self.isSandbox = isSandbox
        self.url = url
        self.onAction = onAction
        self.shouldShowLoader = shouldShowLoader
    }

    public var body: some View {
        #if os(iOS)
            ZStack {
                WebViewComponent
                if isLoading && shouldShowLoader {
                    VStack {
                        AccrueLoader()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.8))
                    .edgesIgnoringSafeArea(.all)
                }
            }
            .onReceive(contextData.objectWillChange) { _ in
                propagateContextDataChanges()
            }
        #endif
    }

    public func handleEvent(event: String) {
        contextData.setAction(action: event)
    }

    private func propagateContextDataChanges() {
        #if os(iOS)
            let webView = WebViewComponent
            webView.triggerContextDataRefresh()
        #endif
    }

    private func buildURL(isSandbox: Bool, url: String?) -> URL? {
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
            urlComponents?.queryItems?.append(
                URLQueryItem(name: "redirectionToken", value: redirectionToken))
        }

        return urlComponents?.url
    }

}
