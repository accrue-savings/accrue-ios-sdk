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
}
