import SwiftUI


public struct AccrueWallet: View {
    public let merchantId: String
    public let redirectionToken: String
    public var onSignIn: ((String) -> Void)?
    public var contextData: ContextData?
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
