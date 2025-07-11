/// Organized event constants with clear directional flow
public struct AccrueEvents {

    static let EventHandlerName: String = "AccrueWallet"

    /// Events sent FROM the SDK TO the WebView
    /// These are events/actions that the iOS app triggers and sends to the web interface
    public struct OutgoingToWebView {

        /// Direct function calls to execute in the webview
        public struct Functions {
            static let GoToHomeScreen: String = "__GO_TO_HOME_SCREEN"
            static let SetContextData: String = "__SET_IOS_CONTEXT_DATA"
            static let GenerateAppleWalletPushProvisioningToken: String =
                "__GENERATE_APPLE_WALLET_PUSH_PROVISIONING_TOKEN"
            static let AppleWalletProvisioningResult: String = "__APPLE_WALLET_PROVISIONING_RESULT"
            static let AppleWalletProvisioningIsSupportedResponse: String =
                "__APPLE_WALLET_PROVISIONING_IS_SUPPORTED_RESPONSE"
        }

        /// Event keys to dispatch to the webview
        public struct EventKeys {
            static let ContextChangedEvent: String = "AccrueWallet::ContextChanged"
            // @deprecated Use GenerateAppleWalletPushProvisioningToken instead
            static let GenerateAppleWalletPushProvisioningToken: String =
                "AccrueWallet::AppleWalletProvisioningSignRequest"
            // @deprecated Use GenerateAppleWalletPushProvisioningToken instead
            static let AppleWalletProvisioningResult: String =
                "AccrueWallet::AppleWalletProvisioningResult"
        }

        /// External events exposed to the SDK consumers
        public struct ExternalEvents {
            static let TabPressed: String = "AccrueWallet::AccrueTabPressed"
        }
    }

    /// Events received FROM the WebView TO the SDK
    /// These are events that the web interface triggers and sends to the iOS app
    public struct IncomingFromWebView {

        static let SignInPerformedMessage: String = "AccrueWallet::SignInPerformed"
        static let AppleWalletProvisioningRequested: String =
            "AccrueWallet::AppleWalletProvisioningRequested"
        static let AppleWalletProvisioningResponse: String =
            "AccrueWallet::AppleWalletProvisioningResponse"
        static let AppleWalletProvisioningIsSupportedRequested: String =
            "AccrueWallet::AppleWalletProvisioningIsSupportedRequested"
    }
}
