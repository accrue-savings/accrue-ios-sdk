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
    @State private var resolvedWidgetURL: URL?
    @State private var requestedURLConfigurationKey: String?

    @ObservedObject public var contextData: AccrueContextData
    #if os(iOS)
        private func WebViewComponent(url: URL) -> AccrueWebView {
            AccrueWebView(
                url: url,
                contextData: contextData,
                onAction: onAction,
                isLoading: $isLoading
            )
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
                if let resolvedWidgetURL = resolvedWidgetURL {
                    WebViewComponent(url: resolvedWidgetURL)
                }

                if (isLoading || resolvedWidgetURL == nil) && shouldShowLoader {
                    VStack {
                        AccrueLoader()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.8))
                    .edgesIgnoringSafeArea(.all)
                }
            }
            .onAppear {
                resolveWidgetURL()
            }
            .onChange(of: merchantId) { _ in
                resolveWidgetURL()
            }
            .onChange(of: redirectionToken) { _ in
                resolveWidgetURL()
            }
            .onChange(of: isSandbox) { _ in
                resolveWidgetURL()
            }
            .onChange(of: url) { _ in
                resolveWidgetURL()
            }
            .onReceive(contextData.objectWillChange) { _ in
                propagateContextDataChanges()
            }
        #endif
    }

    public func handleEvent(event: String) {
        print("🔍 AccrueWallet.handleEvent called with event: \(event)")

        #if os(iOS)
            AccrueSDKURLResolver.shared.resolveWidgetURL(
                isSandbox: isSandbox,
                overrideURL: url,
                merchantId: merchantId,
                redirectionToken: redirectionToken
            ) { result in
                switch result {
                case .success(let resolvedURL):
                    AccrueWebView.sendEventDirectly(to: resolvedURL, event: event)
                    print("✅ AccrueWallet.handleEvent completed - event sent to webview")
                case .failure(let error):
                    print("❌ AccrueWallet.handleEvent failed to resolve widget URL: \(error)")
                }
            }
        #endif
    }

    private func propagateContextDataChanges() {
        #if os(iOS)
            // Only refresh context data, not actions
            guard let resolvedWidgetURL = resolvedWidgetURL else {
                return
            }

            WebViewComponent(url: resolvedWidgetURL).triggerContextDataRefresh()
        #endif
    }

    private func resolveWidgetURL() {
        let urlConfigurationKey = [
            merchantId,
            redirectionToken ?? "",
            isSandbox ? "sandbox" : "production",
            url ?? "",
        ].joined(separator: "|")

        guard requestedURLConfigurationKey != urlConfigurationKey else {
            return
        }

        requestedURLConfigurationKey = urlConfigurationKey
        resolvedWidgetURL = nil
        isLoading = true

        AccrueSDKURLResolver.shared.resolveWidgetURL(
            isSandbox: isSandbox,
            overrideURL: url,
            merchantId: merchantId,
            redirectionToken: redirectionToken
        ) { result in
            guard requestedURLConfigurationKey == urlConfigurationKey else {
                return
            }

            switch result {
            case .success(let resolvedURL):
                resolvedWidgetURL = resolvedURL
            case .failure(let error):
                requestedURLConfigurationKey = nil
                print("❌ AccrueWallet failed to resolve widget URL: \(error)")
            }

            isLoading = false
        }
    }

}
