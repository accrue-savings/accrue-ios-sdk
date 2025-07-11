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
    @State private var sendEventCallback: ((String) -> Void)?

    @ObservedObject public var contextData: AccrueContextData
    #if os(iOS)
        private var WebViewComponent: AccrueWebView {
            let fallbackUrl = URL(string: AppConstants.productionUrl)!
            let url = buildURL(isSandbox: isSandbox, url: url) ?? fallbackUrl

            let webView = AccrueWebView(
                url: url,
                contextData: contextData,
                onAction: onAction,
                isLoading: $isLoading,
                onEventCallback: { callback in
                    // Store the callback for sending events
                    print("🔧 AccrueWallet: onEventCallback being set up...")
                    DispatchQueue.main.async {
                        print("✅ AccrueWallet: Setting sendEventCallback")
                        self.sendEventCallback = callback
                    }
                }
            )

            return webView
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
        print("🔍 AccrueWallet.handleEvent called with event: \(event)")

        #if os(iOS)
            if sendEventCallback == nil {
                print(
                    "⚠️ AccrueWallet: sendEventCallback is nil! The webview might not be initialized yet."
                )
            } else {
                print("✅ AccrueWallet: sendEventCallback exists, calling it with event: \(event)")
            }

            // Send event directly to webview using callback
            sendEventCallback?(event)

            if sendEventCallback == nil {
                print(
                    "💡 AccrueWallet: Trying alternative approach using static webview instances...")
                // Alternative approach: use static webview instances directly
                let fallbackUrl = URL(string: AppConstants.productionUrl)!
                let url = buildURL(isSandbox: isSandbox, url: url) ?? fallbackUrl
                AccrueWebView.sendEventDirectly(to: url, event: event)
            }
        #endif

        print("✅ AccrueWallet.handleEvent completed - event sent to webview")
    }

    private func propagateContextDataChanges() {
        #if os(iOS)
            // Only refresh context data, not actions
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
