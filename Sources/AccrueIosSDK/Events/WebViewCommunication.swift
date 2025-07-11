#if canImport(UIKit)
    import Foundation
    import WebKit

    @available(iOS 13.0, macOS 10.15, *)
    public class WebViewCommunication {

        // MARK: - Outgoing Events (to WebView)

        /// Sends a custom event to the webview by injecting JavaScript
        /// - Parameters:
        ///   - webView: The WKWebView instance to send the event to
        ///   - eventName: The name of the JavaScript function to call
        ///   - arguments: The arguments to pass to the function (as a JSON string)
        ///   - completion: Optional completion handler with result and error
        public static func sendCustomEvent(
            to webView: WKWebView,
            eventName: String,
            arguments: String = "",
            completion: ((Any?, Error?) -> Void)? = nil
        ) {
            let script = """
                (function() {
                    if (typeof window !== "undefined" && typeof window.\(eventName) === "function") {
                        window.\(eventName)(\(arguments));
                    }
                    return "Script injected successfully";
                })();
                """

            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print(
                        "WebViewCommunication: JavaScript injection error: \(error.localizedDescription)"
                    )
                } else {
                    print(
                        "WebViewCommunication: JavaScript executed successfully: \(String(describing: result))"
                    )
                }
                completion?(result, error)
            }
        }

        /// Sends a custom event and clears the context data action upon success
        /// - Parameters:
        ///   - webView: The WKWebView instance to send the event to
        ///   - eventName: The name of the JavaScript function to call
        ///   - arguments: The arguments to pass to the function (as a JSON string)
        ///   - contextData: The context data to clear the action from after successful send
        public static func sendCustomEventAndClearAction(
            to webView: WKWebView,
            eventName: String,
            arguments: String = "",
            contextData: AccrueContextData?
        ) {
            sendCustomEvent(
                to: webView,
                eventName: eventName,
                arguments: arguments
            ) { result, error in
                if error == nil {
                    contextData?.clearAction()
                }
            }
        }

        // MARK: - Incoming Events (from WebView)

        /// Handles incoming events from the webview
        /// - Parameters:
        ///   - message: The WKScriptMessage received from the webview
        ///   - webView: The WKWebView instance (optional, for fallback)
        ///   - onAction: Callback for handling custom actions
        /// - Returns: Boolean indicating if the event was handled
        public static func handleIncomingEvent(
            _ message: WKScriptMessage,
            webView: WKWebView? = nil,
            onAction: ((String) -> Void)? = nil
        ) -> Bool {
            print("WebViewCommunication: Received message: \(message.body)")

            guard message.name == AccrueEvents.IncomingFromWebView.EventHandlerName,
                let body = message.body as? String
            else {
                return false
            }

            guard let data = body.data(using: .utf8),
                let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let type = envelope["key"] as? String
            else {
                // If we can't parse the event, pass it to the generic handler
                onAction?(body)
                return true
            }

            // Handle specific event types
            switch type {
            case AccrueEvents.IncomingFromWebView.AppleWalletProvisioningRequested:
                return handleAppleWalletProvisioningRequested(
                    envelope: envelope,
                    webView: webView ?? message.webView,
                    fallbackAction: onAction,
                    originalBody: body
                )

            case AccrueEvents.IncomingFromWebView.AppleWalletProvisioningSignResponse:
                return handleAppleWalletProvisioningSignResponse(envelope: envelope)

            default:
                // Pass unhandled events to the generic handler
                onAction?(body)
                return true
            }
        }

        // MARK: - Private Event Handlers

        private static func handleAppleWalletProvisioningRequested(
            envelope: [String: Any],
            webView: WKWebView?,
            fallbackAction: ((String) -> Void)?,
            originalBody: String
        ) -> Bool {
            guard let wv = webView else {
                fallbackAction?(originalBody)
                return true
            }

            print("WebViewCommunication: Starting in-app provisioning...")
            AppleWalletPushProvisioningManager.shared.start(
                from: wv,
                with: envelope["data"] as? [String: String] ?? [:]
            )
            return true
        }

        private static func handleAppleWalletProvisioningSignResponse(
            envelope: [String: Any]
        ) -> Bool {
            print("WebViewCommunication: Handling backend response for in-app provisioning...")
            if let raw = envelope["data"] as? String {
                AppleWalletPushProvisioningManager.shared.handleBackendResponse(rawJSON: raw)
            }
            return true
        }
    }

#endif
