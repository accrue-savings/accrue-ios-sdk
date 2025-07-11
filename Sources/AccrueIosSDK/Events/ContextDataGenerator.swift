#if canImport(UIKit)
    import Foundation
    import WebKit

    @available(iOS 13.0, macOS 10.15, *)
    public class ContextDataGenerator {

        // MARK: - Context Data Script Generation

        /// Generates the JavaScript code to inject context data into the webview
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
        }

        // MARK: - Context Data Management

        /// Injects context data into the webview at document start
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
        public static func refreshContextData(
            in webView: WKWebView,
            contextData: AccrueContextData,
            completion: ((Any?, Error?) -> Void)? = nil
        ) {
            let contextDataScript = generateContextDataScript(contextData: contextData)
            print("ContextDataGenerator: Refreshing contextData: \(contextDataScript)")

            // First execute the JavaScript to set up the context data in the window object
            WebViewCommunication.executeJavaScript(
                in: webView,
                script: contextDataScript,
                onSuccess: {
                    WebViewCommunication.callCustomFunction(
                        to: webView,
                        functionName: AccrueEvents.OutgoingToWebView.Functions.SetContextData,
                        arguments: "window[\"\(AccrueEvents.EventHandlerName)\"].contextData"
                    )
                },
                completion: completion
            )
        }

        /// Handles context data changes and triggers appropriate actions
        public static func handleContextDataAction(
            in webView: WKWebView,
            action: String?,
            contextData: AccrueContextData? = nil
        ) {
            print(
                "🔍 ContextDataGenerator.handleContextDataAction called with action: \(action ?? "nil")"
            )

            guard let action = action else {
                print(
                    "⚠️ ContextDataGenerator.handleContextDataAction: No action provided, returning early"
                )
                return
            }

            switch action {
            case AccrueEvents.OutgoingToWebView.ExternalEvents.TabPressed:
                print("📱 ContextDataGenerator: Processing TabPressed event")
                WebViewCommunication.callCustomFunctionAndClearAction(
                    to: webView,
                    functionName: AccrueEvents.OutgoingToWebView.Functions.GoToHomeScreen,
                    contextData: contextData
                )
                print("✅ ContextDataGenerator: TabPressed event processed successfully")
            default:
                print("❌ ContextDataGenerator: Event not supported: \(action)")
            }
        }
    }

#endif
