#if canImport(UIKit)
    import Foundation
    import WebKit

    @available(iOS 13.0, macOS 10.15, *)
    public class ContextDataGenerator {

        // MARK: - Context Data Script Generation

        /// Generates the JavaScript code to inject context data into the webview
        /// - Parameter contextData: The AccrueContextData to convert to JavaScript
        /// - Returns: A JavaScript string that sets up the context data in the webview
        public static func generateContextDataScript(contextData: AccrueContextData) -> String {
            let userData = contextData.userData
            let settingsData = contextData.settingsData
            let deviceContextData = AccrueDeviceContextData()
            let additionalDataJSON = UserDataHelper.parseDictionaryToJSONString(
                contextData.userData.additionalData)

            return """
                (function() {
                      window["\(AccrueEvents.EventHandlerName)"] = {
                          "contextData": {
                              "userData": {
                                  "referenceId": \(userData.referenceId.map { "\"\($0)\"" } ?? "null"),
                                  "email": \(userData.email.map { "\"\($0)\"" } ?? "null"),
                                  "phoneNumber": \(userData.phoneNumber.map { "\"\($0)\"" } ?? "null"),
                                  "additionalData": \(additionalDataJSON)
                              },
                              "settingsData": {
                                  "shouldInheritAuthentication": \(settingsData.shouldInheritAuthentication)
                              },
                              "deviceData": {
                                  "sdk": "\(deviceContextData.sdk)",
                                  "sdkVersion": "\(deviceContextData.sdkVersion ?? "null")",
                                  "brand": "\(deviceContextData.brand ?? "null")",
                                  "deviceName": "\(deviceContextData.deviceName ?? "null")",
                                  "deviceType": "\(deviceContextData.deviceType ?? "")",
                                  "deviceYearClass": "\(deviceContextData.deviceYearClass ?? 0)",
                                  "isDevice": \(deviceContextData.isDevice),
                                  "manufacturer": "\(deviceContextData.manufacturer ?? "null")",
                                  "modelName": "\(deviceContextData.modelName ?? "null")",
                                  "osBuildId": "\(deviceContextData.osBuildId ?? "null")",
                                  "osInternalBuildId": "\(deviceContextData.osInternalBuildId ?? "null")",
                                  "osName": "\(deviceContextData.osName ?? "null")",
                                  "osVersion": "\(deviceContextData.osVersion ?? "null")",
                                  "modelId": "\(deviceContextData.modelId ?? "null")"
                              }
                          }
                      };
                     
                })();
                """

            // Calling both methods for backwards compatibility
            WebViewCommunication.dispatchCustomEvent(
                to: webView,
                eventName: AccrueEvents.OutgoingToWebView.EventKeys.ContextChangedEvent,
                eventData: "window[\"\(AccrueEvents.EventHandlerName)\"].contextData"
            )
            WebViewCommunication.callCustomFunction(
                to: webView,
                functionName: AccrueEvents.OutgoingToWebView.Functions.SetContextData,
                arguments: "window[\"\(AccrueEvents.EventHandlerName)\"].contextData"
            )
        }

        // MARK: - Context Data Management

        /// Injects context data into the webview at document start
        /// - Parameters:
        ///   - userController: The WKUserContentController to add the script to
        ///   - contextData: The AccrueContextData to inject
        public static func injectContextData(
            into userController: WKUserContentController,
            contextData: AccrueContextData
        ) {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            print("ContextDataGenerator: Injecting contextData: \(contextDataScript)")

            let userScript = WKUserScript(
                source: contextDataScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            userController.addUserScript(userScript)
        }

        /// Refreshes context data in an existing webview
        /// - Parameters:
        ///   - webView: The WKWebView to refresh context data in
        ///   - contextData: The AccrueContextData to refresh with
        ///   - completion: Optional completion handler
        public static func refreshContextData(
            in webView: WKWebView,
            contextData: AccrueContextData,
            completion: ((Any?, Error?) -> Void)? = nil
        ) {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            print("ContextDataGenerator: Refreshing contextData: \(contextDataScript)")

            webView.evaluateJavaScript(contextDataScript) { result, error in
                if let error = error {
                    print(
                        "ContextDataGenerator: Error refreshing context data: \(error.localizedDescription)"
                    )
                } else {
                    print("ContextDataGenerator: Context data refreshed successfully")
                }
                completion?(result, error)
            }
        }

        /// Handles context data changes and triggers appropriate actions
        /// - Parameters:
        ///   - webView: The WKWebView to send events to
        ///   - action: The action to perform
        ///   - contextData: The context data to clear the action from after processing
        public static func handleContextDataAction(
            in webView: WKWebView,
            action: String?,
            contextData: AccrueContextData? = nil
        ) {
            guard let action = action else { return }

            switch action {
            case AccrueEvents.OutgoingToWebView.ExternalEvents.TabPressed:
                WebViewCommunication.callCustomFunctionAndClearAction(
                    to: webView,
                    functionName: AccrueEvents.OutgoingToWebView.Functions.GoToHomeScreen,
                    contextData: contextData
                )
            default:
                print("ContextDataGenerator: Event not supported: \(action)")
            }
        }
    }

#endif
