#if canImport(UIKit)
    import Foundation
    import WebKit

    @available(iOS 13.0, macOS 10.15, *)
    public class WebViewCommunication {

        // MARK: - Outgoing Events (to WebView)

        /// Executes JavaScript in the webview with a success callback
        public static func executeJavaScript(
            in webView: WKWebView,
            script: String,
            onSuccess: @escaping () -> Void,
            completion: ((Any?, Error?) -> Void)? = nil
        ) {
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print(
                        "WebViewCommunication: Error executing JavaScript: \(error.localizedDescription)"
                    )
                    completion?(result, error)
                } else {
                    print("WebViewCommunication: JavaScript executed successfully")
                    onSuccess()
                    completion?(result, error)
                }
            }
        }

        /// Calls a custom function in the webview by injecting JavaScript
        public static func callCustomFunction(
            to webView: WKWebView,
            functionName: String,
            arguments: String = "",
            completion: ((Any?, Error?) -> Void)? = nil
        ) {
            let script = """
                (function() {
                    if (typeof window !== "undefined" && typeof window.\(functionName) === "function") {
                        window.\(functionName)(\(arguments));
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

        /// Dispatches a custom event to the webview using the CustomEvent API
        // @deprecated Use useCallCustomFunction instead
        public static func dispatchCustomEvent(
            to webView: WKWebView,
            eventName: String,
            eventData: String = "{}",
            completion: ((Any?, Error?) -> Void)? = nil
        ) {
            let script = """
                (function() {
                    if (typeof window !== "undefined") {
                        var event = new CustomEvent("\(eventName)", {
                            detail: \(eventData)
                        });
                        window.dispatchEvent(event);
                        return "Custom event dispatched successfully";
                    }
                    return "Window not available";
                })();
                """

            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print(
                        "WebViewCommunication: Custom event dispatch error: \(error.localizedDescription)"
                    )
                } else {
                    print(
                        "WebViewCommunication: Custom event dispatched successfully: \(String(describing: result))"
                    )
                }
                completion?(result, error)
            }
        }

        /// Calls a custom function and clears the context data action upon success
        public static func callCustomFunctionAndClearAction(
            to webView: WKWebView,
            functionName: String,
            arguments: String = "",
            contextData: AccrueContextData?
        ) {
            callCustomFunction(
                to: webView,
                functionName: functionName,
                arguments: arguments
            ) { result, error in
                if error == nil {
                    contextData?.clearAction()
                }
            }
        }

        // MARK: - Incoming Events (from WebView)

        /// Handles incoming events from the webview
        public static func handleIncomingEvent(
            _ message: WKScriptMessage,
            webView: WKWebView? = nil,
            onAction: ((String) -> Void)? = nil
        ) -> Bool {
            print("WebViewCommunication: Received message: \(message.body)")

            guard message.name == AccrueEvents.EventHandlerName,
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
                handleAppleWalletProvisioningRequested(
                    envelope: envelope,
                    webView: webView ?? message.webView,
                    fallbackAction: onAction,
                    originalBody: body
                )
                onAction?(body)
                return true

            case AccrueEvents.IncomingFromWebView.AppleWalletProvisioningResponse:
                handleAppleWalletProvisioningResponse(envelope: envelope)
                onAction?(body)
                return true

            case AccrueEvents.IncomingFromWebView.AppleWalletProvisioningIsSupportedRequested:
                handleAppleWalletProvisioningIsSupportedRequested(
                    envelope: envelope,
                    webView: webView ?? message.webView,
                    fallbackAction: onAction,
                    originalBody: body
                )
                onAction?(body)
                return true

            default:
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
        ) {
            guard let wv = webView else {
                fallbackAction?(originalBody)
                return
            }

            print("WebViewCommunication: Starting in-app provisioning...")
            AppleWalletPushProvisioningManager.shared.start(
                from: wv,
                with: envelope["data"] as? [String: String] ?? [:]
            )
        }

        private static func handleAppleWalletProvisioningResponse(
            envelope: [String: Any]
        ) {
            print("WebViewCommunication: Handling backend response for in-app provisioning...")
            if let raw = envelope["data"] as? String {
                AppleWalletPushProvisioningManager.shared.handleBackendResponse(rawJSON: raw)
            }
        }

        private static func handleAppleWalletProvisioningIsSupportedRequested(
            envelope: [String: Any],
            webView: WKWebView?,
            fallbackAction: ((String) -> Void)?,
            originalBody: String
        ) {
            guard let wv = webView else {
                fallbackAction?(originalBody)
                return
            }

            print("WebViewCommunication: Checking push provisioning support...")
            AppleWalletPushProvisioningManager.shared.checkPushProvisioningSupport(from: wv)
        }
    }

#endif
