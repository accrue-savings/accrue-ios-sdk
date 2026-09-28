import XCTest

@testable import AccrueIosSDK

private final class FailingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

final class AccrueIosSDKTests: XCTestCase {

    func testEventHandling() throws {
        // Test that AccrueWallet can be instantiated with event handling
        let contextData = AccrueContextData()
        var receivedEvents: [String] = []

        let accrueWallet = AccrueWallet(
            merchantId: "test-merchant",
            redirectionToken: "test-token",
            isSandbox: false,
            url: "http://127.0.0.1:1", // Resolve locally; never fetch production configuration in tests.
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
            stableReferenceId: "stable-ref",
            email: "test@example.com",
            phoneNumber: "+1234567890",
            additionalData: ["key": "value"]
        )

        XCTAssertEqual(contextData.userData.referenceId, "test-ref")
        XCTAssertEqual(contextData.userData.stableReferenceId, "stable-ref")
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

    func testWidgetURLBuilderUsesRemoteProductionBaseURL() throws {
        let url = try AccrueWidgetURLBuilder.buildURL(
            sdkURLs: AccrueSDKURLs(
                production: "https://embed.example.com",
                sandbox: "https://sandbox.example.com"
            ),
            isSandbox: false,
            overrideURL: nil,
            merchantId: "merchant-1",
            redirectionToken: "token-1"
        )

        XCTAssertEqual(
            url.absoluteString,
            "https://embed.example.com/webview?merchantId=merchant-1&redirectionToken=token-1"
        )
    }

    func testWidgetURLBuilderUsesRemoteSandboxBaseURL() throws {
        let url = try AccrueWidgetURLBuilder.buildURL(
            sdkURLs: AccrueSDKURLs(
                production: "https://embed.example.com",
                sandbox: "https://sandbox.example.com"
            ),
            isSandbox: true,
            overrideURL: nil,
            merchantId: "merchant-1",
            redirectionToken: nil
        )

        XCTAssertEqual(
            url.absoluteString,
            "https://sandbox.example.com/webview?merchantId=merchant-1"
        )
    }

    func testWidgetURLBuilderPreservesExistingWebviewPath() throws {
        let url = try AccrueWidgetURLBuilder.buildURL(
            sdkURLs: AccrueSDKURLs(
                production: "https://embed.example.com/webview",
                sandbox: "https://sandbox.example.com/webview"
            ),
            isSandbox: false,
            overrideURL: nil,
            merchantId: "merchant-1",
            redirectionToken: nil
        )

        XCTAssertEqual(
            url.absoluteString,
            "https://embed.example.com/webview?merchantId=merchant-1"
        )
    }

    func testWidgetURLBuilderCanUseProductionFallbackURL() throws {
        let url = try AccrueWidgetURLBuilder.buildFallbackURL(
            isSandbox: false,
            merchantId: "merchant-1",
            redirectionToken: "token-1"
        )

        XCTAssertEqual(
            url.absoluteString,
            "https://embed.accruesavings.com/webview?merchantId=merchant-1&redirectionToken=token-1"
        )
    }

    func testWidgetURLBuilderCanUseSandboxFallbackURL() throws {
        let url = try AccrueWidgetURLBuilder.buildFallbackURL(
            isSandbox: true,
            merchantId: "merchant-1",
            redirectionToken: nil
        )

        XCTAssertEqual(
            url.absoluteString,
            "https://embed-sandbox.accruesavings.com/webview?merchantId=merchant-1"
        )
    }

    func testSDKURLResolverFallsBackToProductionURLWhenRemoteConfigFails() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingURLProtocol.self]
        let resolver = AccrueSDKURLResolver(
            endpoint: URL(string: "https://example.com/sdk-urls")!,
            session: URLSession(configuration: configuration)
        )
        let expectation = expectation(description: "resolves fallback widget URL")

        resolver.resolveWidgetURL(
            isSandbox: false,
            overrideURL: nil,
            merchantId: "merchant-1",
            redirectionToken: "token-1"
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertEqual(
                    url.absoluteString,
                    "https://embed.accruesavings.com/webview?merchantId=merchant-1&redirectionToken=token-1"
                )
            case .failure(let error):
                XCTFail("Expected fallback URL, got error: \(error)")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
