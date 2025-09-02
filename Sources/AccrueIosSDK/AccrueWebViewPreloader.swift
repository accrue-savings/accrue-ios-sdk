#if canImport(UIKit)

    import Foundation
    import SwiftUI
    import WebKit
    import UIKit

    @available(iOS 13.0, macOS 10.15, *)
    public class AccrueWebViewPreloader: ObservableObject {
        public static let shared = AccrueWebViewPreloader()

        private var preloadedWebViews: [URL: WKWebView] = [:]
        private let queue = DispatchQueue(label: "com.accrue.webview.preloader", qos: .background)

        private init() {}

        /// Preload a webview for the given URL in the background
        public func preloadWebView(for url: URL, contextData: AccrueContextData? = nil) {
            queue.async { [weak self] in
                guard let self = self else { return }

                // Check if already preloaded
                if self.preloadedWebViews[url] != nil {
                    print("✅ WebView already preloaded for URL: \(url)")
                    return
                }

                print("🔄 Preloading WebView for URL: \(url)")

                // Create webview configuration
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .default()

                // Create webview
                let webView = WKWebView(
                    frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)

                // Configure webview
                webView.isMultipleTouchEnabled = false
                webView.scrollView.pinchGestureRecognizer?.isEnabled = false
                webView.scrollView.minimumZoomScale = 1.0
                webView.scrollView.maximumZoomScale = 1.0

                if #available(iOS 16.4, *) {
                    webView.isInspectable = true
                }

                // Add script message handler
                let userContentController = webView.configuration.userContentController
                userContentController.add(
                    AccrueWebViewPreloaderCoordinator(), name: AccrueEvents.EventHandlerName)

                // Inject context data if provided
                if let contextData = contextData {
                    ContextDataGenerator.injectContextData(
                        into: userContentController, contextData: contextData)
                }

                // Store the preloaded webview
                self.preloadedWebViews[url] = webView

                // Load the URL
                let request = URLRequest(url: url)
                request.cachePolicy = .useProtocolCachePolicy
                webView.load(request)

                print("✅ WebView preloaded successfully for URL: \(url)")
            }
        }

        /// Get a preloaded webview for the given URL
        public func getPreloadedWebView(for url: URL) -> WKWebView? {
            return preloadedWebViews[url]
        }

        /// Check if a webview is preloaded for the given URL
        public func isPreloaded(for url: URL) -> Bool {
            return preloadedWebViews[url] != nil
        }

        /// Clear all preloaded webviews
        public func clearPreloadedWebViews() {
            preloadedWebViews.removeAll()
        }
    }

    // Coordinator for preloaded webviews
    private class AccrueWebViewPreloaderCoordinator: NSObject, WKScriptMessageHandler {
        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            // Handle messages from preloaded webviews
            // This is a minimal implementation - you might want to store callbacks
            print("📨 Message received from preloaded webview: \(message.name)")
        }
    }

#endif
