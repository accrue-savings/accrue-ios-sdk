public struct AppConstants {
    // Mocked testing environment
    static let sandboxUrl:String = "https://embed-sandbox.accruesavings.com/webview"
    static let productionUrl:String = "https://embed.accruesavings.com/webview"
    // Mocked merchantId
    static let merchantId: String = "08b13e48-06be-488f-9a93-91f59d94f30d"
    static let redirectionToken = "redirection-token"
}
public struct AccrueWebEvents {
    static let EventHandlerName:String = "AccrueWallet"
    static let AccrueWalletSignInPerfomerdMessageKey:String = "AccrueWallet::SignInPerformed"
    static let AccrueWalletContextChangedEventKey:String = "AccrueWallet::ContextChanged"

    //Apple Wallet flow
    static let AppleWalletProvisioningRequested = "AccrueWallet::AppleWalletProvisioningRequested"
    static let AppleWalletProvisioningSignRequest = "AccrueWallet::AppleWalletProvisioningSignRequest"
    static let AppleWalletProvisioningSignResponse = "AccrueWallet::AppleWalletProvisioningSignResponse"
    static let AppleWalletProvisioningResult = "AccrueWallet::AppleWalletProvisioningResult"
}
