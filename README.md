# Accrue Ios SDK

Refer to the [Ios Docs](https://docs.accruesavings.com/docs/integration/mobile/sdk/ios) for more information.

## WebView Preloading

The Accrue iOS SDK now supports preloading WebViews in the background to improve user experience by reducing loading times when users navigate to the wallet tab.

### Why Preload?

- **Faster Navigation**: WebViews load in the background while the app is starting up
- **Better UX**: Users don't experience loading delays when tapping the wallet tab
- **Network Optimization**: Takes advantage of faster network connections during app startup

### How to Use

#### Option 1: Using the Main SDK Class (Recommended)

```swift
import AccrueIosSDK

// Preload a specific wallet configuration
AccrueIosSDK.preloadWalletWebView(
    merchantId: "your-merchant-id",
    redirectionToken: "optional-token",
    isSandbox: false,
    customUrl: nil,
    contextData: AccrueContextData()
) { success in
    if success {
        print("✅ WebView preloaded successfully")
    } else {
        print("❌ WebView preloading failed")
    }
}

// Or preload a specific URL directly
let url = URL(string: "https://embed.accruesavings.com/webview")!
AccrueIosSDK.preloadWebView(for: url) { success in
    print("Preloading result: \(success)")
}
```

#### Option 2: Using AccrueWallet Instance

```swift
let wallet = AccrueWallet(
    merchantId: "your-merchant-id",
    redirectionToken: "optional-token",
    isSandbox: false,
    contextData: AccrueContextData()
)

// Preload the WebView for this wallet
wallet.preloadWebView { success in
    print("Wallet WebView preloaded: \(success)")
}

// Check if preloaded
if wallet.isWebViewPreloaded() {
    print("WebView is ready!")
}
```

#### Option 3: Using AccrueWebView Directly

```swift
let url = URL(string: "https://embed.accruesavings.com/webview")!
AccrueWebView.preload(for: url) { success in
    print("Direct preloading result: \(success)")
}
```

### Best Practices

1. **Call Early**: Preload WebViews as soon as possible in your app lifecycle (e.g., in `AppDelegate` or `SceneDelegate`)

2. **Handle Failures**: Always provide completion handlers to handle preloading failures gracefully

3. **Memory Management**: The SDK automatically manages preloaded WebViews and transfers them to active instances when needed

4. **Cleanup**: Use `AccrueIosSDK.cleanup()` when your app goes to background or during memory pressure

### Example Implementation

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Preload WebView immediately when app launches
        AccrueIosSDK.preloadWalletWebView(
            merchantId: "your-merchant-id",
            isSandbox: false
        ) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ WebView preloaded successfully")
                } else {
                    print("❌ WebView preloading failed - will load normally when needed")
                }
            }
        }
        
        return true
    }
}
```

### API Reference

#### AccrueIosSDK

- `preloadWebView(for:contextData:completion:)` - Preload a WebView for a specific URL
- `preloadWalletWebView(merchantId:redirectionToken:isSandbox:customUrl:contextData:completion:)` - Preload a WebView for a wallet configuration
- `isWebViewPreloaded(for:)` - Check if a WebView is preloaded
- `clearPreloadedWebViews()` - Clear all preloaded WebViews
- `cleanup()` - Clean up all WebView instances and data

#### AccrueWallet

- `preloadWebView(completion:)` - Preload the WebView for this wallet
- `isWebViewPreloaded()` - Check if the WebView is preloaded

#### AccrueWebView

- `preload(for:contextData:completion:)` - Static method to preload a WebView
- `isPreloaded(for:)` - Check if a WebView is preloaded
- `clearPreloadedWebViews()` - Clear all preloaded WebViews

### Notes

- Preloaded WebViews are automatically transferred to active instances when `AccrueWebView` is created
- The SDK handles memory management and cleanup automatically
- Preloading works on both iOS and macOS (when available)
- Failed preloading attempts don't affect normal WebView creation
