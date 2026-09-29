# Accrue Ios SDK

Refer to the [Ios Docs](https://docs.accruesavings.com/docs/integration/mobile/sdk/ios) for more information.

## Tests

Run the full suite on an iOS simulator (choose its ID with `xcrun simctl list devices available`):

```sh
xcodebuild test -scheme AccrueIosSDK \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath /tmp/accrue-sdk-tests \
  -parallel-testing-enabled NO
```

`AccrueWebViewNavigationTests` hosts the real SwiftUI wrapper and WKWebView against an in-process loopback HTTP server. It covers SPA routing, native destination changes, cached reuse, failed-load recovery on remount, callback/loading ownership, context updates and startup-script order, redirects, explicit reload, the process-recovery delegate callback, and cleanup. Tests do not require production services or accounts. The WebView tests require iOS; a macOS-only test run does not exercise them.
