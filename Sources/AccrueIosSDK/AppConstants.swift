public struct AppConstants {
    // Mocked testing environment
    static let sandboxUrl: String = "https://embed-sandbox.accruesavings.com/webview"
    static let productionUrl: String = "https://embed.accruesavings.com/webview"
    // Mocked merchantId
    static let merchantId: String = "08b13e48-06be-488f-9a93-91f59d94f30d"
    static let redirectionToken = "redirection-token"
}

/// Organized event constants with clear directional flow
public struct AccrueEvents {

    /// Events sent FROM the SDK TO the WebView
    /// These are events/actions that the iOS app triggers and sends to the web interface
    public struct OutgoingToWebView {
        // Context and UI events
        static let ContextChangedEvent = "AccrueWallet::ContextChanged"
        static let TabPressed = "AccrueTabPressed"
        static let GoToHomeScreen = "__GO_TO_HOME_SCREEN"

        // Apple Wallet flow - responses sent to WebView
        static let AppleWalletProvisioningSignRequest =
            "AccrueWallet::AppleWalletProvisioningSignRequest"
        static let AppleWalletProvisioningResult = "AccrueWallet::AppleWalletProvisioningResult"
    }

    /// Events received FROM the WebView TO the SDK
    /// These are events that the web interface triggers and sends to the iOS app
    public struct IncomingFromWebView {
        // Core communication
        static let EventHandlerName = "AccrueWallet"
        static let SignInPerformedMessage = "AccrueWallet::SignInPerformed"

        // Apple Wallet flow - requests received from WebView
        static let AppleWalletProvisioningRequested =
            "AccrueWallet::AppleWalletProvisioningRequested"
        static let AppleWalletProvisioningSignResponse =
            "AccrueWallet::AppleWalletProvisioningSignResponse"
    }
}

// MARK: - Backward Compatibility Aliases
// These maintain compatibility with existing code while we transition

/// @deprecated Use AccrueEvents.IncomingFromWebView instead
public typealias AccrueWebViewEvents = AccrueEvents.IncomingFromWebView

/// @deprecated Use AccrueEvents.OutgoingToWebView instead
public typealias AccrueAppActions = AccrueEvents.OutgoingToWebView
