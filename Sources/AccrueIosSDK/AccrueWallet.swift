import SwiftUI


struct AccrueWallet: View {
    let merchantId: String
    let redirectionToken: String
    var onSignIn: ((String) -> Void)?
    var contextData: ContextData?
    @available(macOS 10.15, *)
    var body: some View {
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
