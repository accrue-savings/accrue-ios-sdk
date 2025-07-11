import Foundation
import PassKit

#if canImport(UIKit)
    import UIKit
    import WebKit
    import os.log

    private let logger = Logger(subsystem: "com.accrue.sdk", category: "PushProvisioning")

    /// Apple Wallet Push Provisioning Manager
    ///
    /// This class manages the complete flow of adding payment cards to Apple Wallet through
    /// a web-based interface. The flow involves:
    /// 1. JavaScript initiates provisioning with card details
    /// 2. Native code validates and presents Apple Wallet UI
    /// 3. Apple generates cryptographic certificates and nonce
    /// 4. Data is sent to backend for processing
    /// 5. Backend returns encrypted pass data
    /// 6. Pass is added to Apple Wallet
    final class AppleWalletPushProvisioningManager: NSObject, PKAddPaymentPassViewControllerDelegate
    {

        static let shared = AppleWalletPushProvisioningManager()
        private override init() {}

        // MARK: - Core Properties

        /// Reference to the web view that initiated the provisioning request
        /// Used to communicate back to JavaScript throughout the flow
        private weak var webView: WKWebView?

        /// Completion handler provided by PassKit during certificate generation
        /// Must be called with final PKAddPaymentPassRequest to complete provisioning
        private var pendingCompletion: ((PKAddPaymentPassRequest) -> Void)?

        /// Safety timer to prevent indefinite waiting for backend response
        /// Automatically fails the provisioning after 30 seconds
        private var timeoutTimer: Timer?

        // MARK: - Main Entry Point (Called from JavaScript)

        /**
     * Initiates Apple Wallet provisioning flow from web interface
     *
     * This is the main entry point called when JavaScript wants to add a card to Apple Wallet.
     * Validates input, checks device capabilities, and presents the PassKit UI.
     *
     * @param webView The web view making the request (for callbacks)
     * @param config Dictionary containing card details (cardholderName, cardSuffix, description)
     */
        func start(from webView: WKWebView, with config: [String: String]) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // STEP 1: Validate required card information
                guard
                    let cardholder = config["cardholderName"]?.trimmingCharacters(
                        in: .whitespacesAndNewlines),
                    let suffix = config["cardSuffix"]?.trimmingCharacters(
                        in: .whitespacesAndNewlines),
                    let desc = config["description"]?.trimmingCharacters(
                        in: .whitespacesAndNewlines),
                    !cardholder.isEmpty, !suffix.isEmpty, !desc.isEmpty
                else {
                    logger.error("Invalid configuration provided")
                    self.notifyError(to: webView, message: "Invalid configuration")
                    return
                }

                // STEP 2: Check if device supports adding passes to Apple Wallet
                guard PKAddPaymentPassViewController.canAddPaymentPass() else {
                    logger.error("Cannot add payment pass on this device")
                    self.notifyError(to: webView, message: "Device cannot add payment passes")
                    return
                }

                // STEP 3: Find the top view controller to present PassKit UI
                guard let hostVC = self.findTopViewController() else {
                    logger.error("No host view controller found")
                    self.notifyError(to: webView, message: "No host view controller available")
                    return
                }

                // Store webView reference for later callbacks
                self.webView = webView

                // STEP 4: Configure the payment pass request with card details
                guard
                    let passConfig = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2)
                else {
                    logger.error("Unable to create pass configuration")
                    self.notifyError(to: webView, message: "Failed to create pass configuration")
                    return
                }

                // Set payment style for iOS 15+ (improved UI)
                if #available(iOS 15.0, *) {
                    passConfig.style = .payment
                }

                // Configure card display information
                passConfig.cardholderName = cardholder
                passConfig.primaryAccountSuffix = suffix
                passConfig.localizedDescription = desc
                passConfig.paymentNetwork = .visa

                // STEP 5: Create and present the PassKit view controller
                guard
                    let addVC = PKAddPaymentPassViewController(
                        requestConfiguration: passConfig, delegate: self)
                else {
                    logger.error("Unable to create pass view controller")
                    self.notifyError(to: webView, message: "Failed to create pass view controller")
                    return
                }

                // Present the Apple Wallet add card UI
                hostVC.present(addVC, animated: true)
            }
        }

        // MARK: - PassKit Delegate Methods (Core Provisioning Protocol)

        /**
     * Called by PassKit when certificates are ready for backend processing
     *
     * This is the critical step where Apple provides cryptographic certificates
     * and a nonce that must be sent to the card issuer's backend for processing.
     * The backend will use these to create an encrypted pass.
     *
     * @param controller The PassKit view controller
     * @param certificates Array of certificate data from Apple
     * @param nonce Random data for cryptographic security
     * @param nonceSignature Apple's signature of the nonce
     * @param handler Completion handler that MUST be called with final pass request
     */
        func addPaymentPassViewController(
            _ controller: PKAddPaymentPassViewController,
            generateRequestWithCertificateChain certificates: [Data],
            nonce: Data,
            nonceSignature: Data,
            completionHandler handler: @escaping (PKAddPaymentPassRequest) -> Void
        ) {

            // Store completion handler for later use when backend responds
            pendingCompletion = handler

            // Start timeout protection - backend must respond within 30 seconds
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) {
                [weak self] _ in
                logger.error("Provisioning request timed out")
                self?.completeWithError("Request timed out")
            }

            // Prepare cryptographic data for backend transmission
            let payload: [String: Any] = [
                "certificates": certificates.map { $0.base64EncodedString() },
                "nonce": nonce.base64EncodedString(),
                "nonceSignature": nonceSignature.base64EncodedString(),
            ]

            do {
                // Serialize payload to JSON for JavaScript transmission
                let jsonData = try JSONSerialization.data(withJSONObject: payload)
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    logger.error("Failed to encode JSON as UTF-8")
                    completeWithError("Failed to encode provisioning data")
                    return
                }

                // Send certificate data to JavaScript for backend processing
                DispatchQueue.main.async { [weak self] in
                    guard let webView = self?.webView else {
                        logger.error("WebView reference lost")
                        self?.completeWithError("WebView reference lost")
                        return
                    }

                    // Dispatch custom event to JavaScript with certificate data
                    // Calling both methods for backwards compatibility
                    WebViewCommunication.dispatchCustomEvent(
                        to: webView,
                        eventName: AccrueEvents.OutgoingToWebView.EventKeys
                            .AppleWalletProvisioningSignRequest,
                        eventData: jsonString
                    )
                    WebViewCommunication.callCustomFunction(
                        to: webView,
                        functionName: AccrueEvents.OutgoingToWebView.Functions
                            .AppleWalletProvisioningSignRequest,
                        arguments: jsonString
                    )

                }
            } catch {
                logger.error(
                    "JSON serialization failed: \(error.localizedDescription, privacy: .public)")
                completeWithError("Failed to serialize provisioning data")
            }
        }

        /**
     * Called when the PassKit flow completes (success or failure)
     *
     * This is the final step - either the pass was successfully added to Apple Wallet
     * or an error occurred. We notify JavaScript of the final result and clean up.
     *
     * @param controller The PassKit view controller
     * @param paymentPass The added pass (nil if failed)
     * @param error Any error that occurred during provisioning
     */
        func addPaymentPassViewController(
            _ controller: PKAddPaymentPassViewController,
            didFinishAdding paymentPass: PKPaymentPass?, error: Error?
        ) {

            // Clean up timers and completion handlers
            cleanup()

            DispatchQueue.main.async { [weak self] in
                // Dismiss the PassKit UI
                controller.dismiss(animated: true)

                guard let webView = self?.webView else {
                    logger.warning("WebView reference lost during completion")
                    return
                }

                // Determine success/failure and prepare result
                let success = error == nil
                let errorMsg = error?.localizedDescription ?? ""

                // Notify JavaScript of final provisioning result
                WebViewCommunication.dispatchCustomEvent(
                    to: webView,
                    eventName: AccrueEvents.OutgoingToWebView.EventKeys
                        .AppleWalletProvisioningResult,
                    eventData:
                        "{\"success\": \(success), \"error\": \"\(errorMsg.replacingOccurrences(of: "\"", with: "\\\""))\"}"
                )
                WebViewCommunication.callCustomFunction(
                    to: webView,
                    functionName: AccrueEvents.OutgoingToWebView.Functions
                        .AppleWalletProvisioningResult,
                    arguments:
                        "{\"success\": \(success), \"error\": \"\(errorMsg.replacingOccurrences(of: "\"", with: "\\\""))\"}"
                )

            }
        }

        // MARK: - Backend Response Handler (Called from JavaScript)

        /**
     * Processes the backend response with encrypted pass data
     *
     * After JavaScript sends certificate data to the backend, the backend returns
     * encrypted pass data. This method processes that response and completes
     * the PassKit provisioning flow.
     *
     * @param rawJSON JSON string containing activationData, encryptedPassData, and ephemeralPublicKey
     */
        func handleBackendResponse(rawJSON: String) {
            guard let data = rawJSON.data(using: .utf8) else {
                logger.error("Invalid UTF-8 in backend response")
                completeWithError("Invalid backend response")
                return
            }

            do {
                // Parse backend response JSON
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String],
                    let activationData = dict["activationData"],
                    let encryptedPassData = dict["encryptedPassData"],
                    let ephemeralPublicKey = dict["ephemeralPublicKey"]
                else {
                    logger.error("Invalid backend response format")
                    completeWithError("Invalid backend response format")
                    return
                }

                // Decode base64-encoded cryptographic data
                guard let activation = Data(base64Encoded: activationData),
                    let encrypted = Data(base64Encoded: encryptedPassData),
                    let ephemeral = Data(base64Encoded: ephemeralPublicKey)
                else {
                    logger.error("Invalid base64 data in backend response")
                    completeWithError("Invalid backend response data")
                    return
                }

                // Ensure we still have a pending completion handler
                guard let completion = pendingCompletion else {
                    logger.error("No pending completion handler")
                    return
                }

                // Create final pass request with backend-provided encrypted data
                let req = PKAddPaymentPassRequest()
                req.activationData = activation
                req.encryptedPassData = encrypted
                req.ephemeralPublicKey = ephemeral

                // Clean up and complete the PassKit flow
                cleanup()
                completion(req)

            } catch {
                logger.error("JSON parsing error: \(error.localizedDescription, privacy: .public)")
                completeWithError("Failed to parse backend response")
            }
        }

        // MARK: - Private Helper Methods

        /**
     * Finds the topmost view controller for presenting PassKit UI
     *
     * Traverses the view controller hierarchy to find the appropriate
     * controller to present the Apple Wallet interface.
     */
        private func findTopViewController() -> UIViewController? {
            guard
                let scene = UIApplication.shared.connectedScenes.first(where: {
                    $0.activationState == .foregroundActive
                }) as? UIWindowScene,
                let window = scene.windows.first(where: \.isKeyWindow),
                let rootVC = window.rootViewController
            else {
                return nil
            }

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            return topVC
        }

        /**
     * Sends error notification to JavaScript
     *
     * Dispatches a custom event to notify the web interface of errors
     * that occur during the provisioning process.
     */
        private func notifyError(to webView: WKWebView, message: String) {
            let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
            WebViewCommunication.dispatchCustomEvent(
                to: webView,
                eventName: AccrueEvents.OutgoingToWebView.EventKeys
                    .AppleWalletProvisioningResult,
                eventData: "{\"success\": false, \"error\": \"\(escapedMessage)\"}"
            )
            WebViewCommunication.callCustomFunction(
                to: webView,
                functionName: AccrueEvents.OutgoingToWebView.Functions
                    .AppleWalletProvisioningResult,
                arguments: "{\"success\": false, \"error\": \"\(escapedMessage)\"}"
            )

        }

        /**
     * Handles error completion for PassKit flow
     *
     * When errors occur, we must still call the PassKit completion handler
     * (with an empty request) to properly terminate the flow.
     */
        private func completeWithError(_ message: String) {
            guard let completion = pendingCompletion else { return }

            cleanup()

            // PassKit requires completion handler to be called even on error
            // Empty request signals failure to PassKit
            completion(PKAddPaymentPassRequest())

            // Also notify JavaScript of the error
            if let webView = webView {
                notifyError(to: webView, message: message)
            }
        }

        /**
     * Cleans up resources and resets state
     *
     * Invalidates timers and clears completion handlers to prevent
     * memory leaks and multiple completions.
     */
        private func cleanup() {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            pendingCompletion = nil
        }
    }

    // MARK: - UIApplication Extension

    /// Helper extension to find the key window across multiple scenes
    /// Provides compatibility for iOS 13+ multi-window support
    extension UIApplication {
        var keyWindow: UIWindow? {
            connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }
        }
    }
#endif
