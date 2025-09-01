// The Swift Programming Language
// https://docs.swift.org/swift-book

#if canImport(UIKit)
    import Foundation
    import SwiftUI

    @available(iOS 13.0, macOS 11.0, *)
    public class AccrueIosSDK {

        // MARK: - WebView Preloading

        /// Preloads a WebView for the given URL in the background
        /// - Parameters:
        ///   - url: The URL to preload
        ///   - contextData: Optional context data to inject
        ///   - completion: Completion handler called when preloading is complete
        public static func preloadWebView(
            for url: URL,
            contextData: AccrueContextData? = nil,
            completion: @escaping (Bool) -> Void = { _ in }
        ) {
            AccrueWebView.preload(for: url, contextData: contextData, completion: completion)
        }

        /// Preloads a WebView for a wallet configuration in the background
        /// - Parameters:
        ///   - merchantId: The merchant ID
        ///   - redirectionToken: Optional redirection token
        ///   - isSandbox: Whether to use sandbox environment
        ///   - customUrl: Optional custom URL
        ///   - contextData: Optional context data to inject
        ///   - completion: Completion handler called when preloading is complete
        public static func preloadWalletWebView(
            merchantId: String,
            redirectionToken: String? = nil,
            isSandbox: Bool = false,
            customUrl: String? = nil,
            contextData: AccrueContextData = AccrueContextData(),
            completion: @escaping (Bool) -> Void = { _ in }
        ) {
            let wallet = AccrueWallet(
                merchantId: merchantId,
                redirectionToken: redirectionToken,
                isSandbox: isSandbox,
                url: customUrl,
                contextData: contextData
            )

            wallet.preloadWebView(completion: completion)
        }

        /// Checks if a WebView is preloaded for the given URL
        /// - Parameter url: The URL to check
        /// - Returns: True if a WebView is preloaded, false otherwise
        public static func isWebViewPreloaded(for url: URL) -> Bool {
            return AccrueWebView.isPreloaded(for: url)
        }

        /// Clears all preloaded WebViews
        public static func clearPreloadedWebViews() {
            AccrueWebView.clearPreloadedWebViews()
        }

        /// Cleans up all WebView instances and data
        public static func cleanup() {
            AccrueWebView.cleanup()
            clearPreloadedWebViews()
        }
    }
#endif
