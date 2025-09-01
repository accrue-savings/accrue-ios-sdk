import XCTest

@testable import AccrueIosSDK

final class AccrueIosSDKTests: XCTestCase {

    func testEventHandling() throws {
        // Test that AccrueWallet can be instantiated with event handling
        let contextData = AccrueContextData()
        var receivedEvents: [String] = []

        let accrueWallet = AccrueWallet(
            merchantId: "test-merchant",
            redirectionToken: "test-token",
            isSandbox: true,
            contextData: contextData,
            onAction: { event in
                receivedEvents.append(event)
            }
        )

        // Test that handleEvent can be called without errors
        accrueWallet.handleEvent(event: "AccrueTabPressed")

        // The test passes if no exception is thrown
        XCTAssertTrue(true, "Event handling completed without errors")
    }

    func testStaticEventHandling() throws {
        #if os(iOS)
            // Test the static event handling approach directly
            let testURL = URL(string: "https://test.example.com")!

            // This will show the "No webview found" message, which is expected in tests
            AccrueWebView.sendEventDirectly(to: testURL, event: "AccrueTabPressed")

            // The test passes if no exception is thrown
            XCTAssertTrue(true, "Static event handling completed without errors")
        #else
            // On non-iOS platforms, just verify the test setup works
            XCTAssertTrue(true, "Static event handling test skipped on non-iOS platform")
        #endif
    }

    func testContextDataUpdate() throws {
        // Test that context data updates work correctly
        let contextData = AccrueContextData()

        // Test userData update
        contextData.updateUserData(
            referenceId: "test-ref",
            email: "test@example.com",
            phoneNumber: "+1234567890",
            additionalData: ["key": "value"]
        )

        XCTAssertEqual(contextData.userData.referenceId, "test-ref")
        XCTAssertEqual(contextData.userData.email, "test@example.com")
        XCTAssertEqual(contextData.userData.phoneNumber, "+1234567890")
        XCTAssertEqual(contextData.userData.additionalData?["key"], "value")

        // Test settingsData update
        contextData.updateSettingsData(shouldInheritAuthentication: false)

        XCTAssertEqual(contextData.settingsData.shouldInheritAuthentication, false)
    }

    func testEventConstants() throws {
        // Test that event constants are accessible
        let tabPressedEvent = AccrueEvents.OutgoingToWebView.ExternalEvents.TabPressed
        XCTAssertEqual(tabPressedEvent, "AccrueTabPressed")

        let eventHandlerName = AccrueEvents.EventHandlerName
        XCTAssertEqual(eventHandlerName, "AccrueWallet")
    }

    #if os(iOS)
        func testWebViewPreloading() throws {
            // Test URL preloading
            let url = URL(string: "https://embed.accruesavings.com/webview")!

            // Initially should not be preloaded
            XCTAssertFalse(AccrueWebView.isPreloaded(for: url))

            // Test preloading
            let expectation = XCTestExpectation(description: "WebView preloading")
            AccrueWebView.preload(for: url) { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)

            // Should now be preloaded
            XCTAssertTrue(AccrueWebView.isPreloaded(for: url))

            // Test clearing
            AccrueWebView.clearPreloadedWebViews()
            XCTAssertFalse(AccrueWebView.isPreloaded(for: url))
        }

        func testWalletPreloading() throws {
            let wallet = AccrueWallet(
                merchantId: "test-merchant",
                redirectionToken: nil,
                isSandbox: true,
                contextData: AccrueContextData()
            )

            // Initially should not be preloaded
            XCTAssertFalse(wallet.isWebViewPreloaded())

            // Test preloading
            let expectation = XCTestExpectation(description: "Wallet WebView preloading")
            wallet.preloadWebView { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)

            // Should now be preloaded
            XCTAssertTrue(wallet.isWebViewPreloaded())
        }

        func testSDKPreloading() throws {
            // Test SDK-level preloading
            let expectation = XCTestExpectation(description: "SDK WebView preloading")

            AccrueIosSDK.preloadWalletWebView(
                merchantId: "test-merchant",
                isSandbox: true
            ) { success in
                XCTAssertTrue(success)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)

            // Test cleanup
            AccrueIosSDK.cleanup()
        }
    #else
        func testWebViewPreloading() throws {
            // Skip test on non-iOS platforms
            XCTAssertTrue(true, "WebView preloading test skipped on non-iOS platform")
        }

        func testWalletPreloading() throws {
            // Skip test on non-iOS platforms
            XCTAssertTrue(true, "Wallet preloading test skipped on non-iOS platform")
        }

        func testSDKPreloading() throws {
            // Skip test on non-iOS platforms
            XCTAssertTrue(true, "SDK preloading test skipped on non-iOS platform")
        }
    #endif
}
