#if os(iOS)
import Network
import SwiftUI
import WebKit
import XCTest
@testable import AccrueIosSDK

/// Exercises the real UIViewRepresentable and WebKit against loopback only.
@MainActor
final class AccrueWebViewNavigationTests: XCTestCase {
    private var server: WalletHTTPFixture!
    private var window: UIWindow!
    private var host: UIHostingController<WalletTestHost>!
    private var model: WalletTestModel!

    override func setUp() async throws {
        server = try WalletHTTPFixture()
        server.start()
        try await eventually { self.server.port != nil }
        model = WalletTestModel(url: server.url("/wallet/boot"))
    }

    override func tearDown() async throws {
        host?.rootView.model.visible = false
        window?.isHidden = true
        window?.rootViewController = nil
        host = nil
        window = nil
        AccrueWebView.cleanup()
        server.stop()
        server = nil
        model = nil
    }

    func testSPARoutingAndRepeatedNativeUpdatesKeepOneDocument() async throws {
        let webView = try await mount()
        try await eventually { webView.url?.path == "/wallet/auth/pin" }
        let token = try await javaScript("window.documentToken", in: webView) as? String
        for _ in 0..<10 {
            model.revision += 1
            try await settle()
        }
        XCTAssertEqual(server.requests.filter { $0.hasPrefix("/wallet/boot") }.count, 1)
        let currentToken = try await javaScript("window.documentToken", in: webView) as? String
        XCTAssertEqual(currentToken, token)
        XCTAssertEqual(webView.url?.path, "/wallet/auth/pin")
    }

    func testConfiguredDestinationChangesLoadOnceAndUpdateEventLookup() async throws {
        let webView = try await mount()
        try await ready(webView)
        model.url = server.url("/wallet/boot?merchantId=second")
        try await eventually { self.server.requests.contains("/wallet/boot?merchantId=second") }
        try await ready(webView)
        AccrueWebView.sendEventDirectly(to: model.url, event: AccrueEvents.OutgoingToWebView.ExternalEvents.TabPressed)
        try await eventuallyJS("window.homeCalls === 1", in: webView)
        AccrueWebView.sendEventDirectly(to: server.url("/wallet/boot"), event: AccrueEvents.OutgoingToWebView.ExternalEvents.TabPressed)
        try await settle()
        let homeCalls = try await javaScript("window.homeCalls", in: webView) as? Int
        XCTAssertEqual(homeCalls, 1, "The old merchant URL must not route into the new merchant document")
        model.url = server.url("/wallet/boot")
        try await eventually { self.server.requests.filter { $0 == "/wallet/boot" }.count >= 2 }
        try await ready(webView)
        XCTAssertEqual(server.requests.filter { $0.hasPrefix("/wallet/boot") }.count, 3)
    }

    func testCachedRemountKeepsDocumentAndRebindsCoordinatorAndMessages() async throws {
        let webView = try await mount()
        try await ready(webView)
        let oldCoordinator = webView.navigationDelegate as? AccrueWebView.Coordinator
        let token = try await javaScript("window.documentToken", in: webView) as? String
        model.visible = false
        try await settle()
        let previousModel = model!
        previousModel.isLoading = false
        model = WalletTestModel(url: previousModel.url)
        model.revision = 42
        model.isLoading = true
        host.rootView = WalletTestHost(model: model)
        try await settle()
        XCTAssertFalse(model.isLoading, "A loaded cached view must synchronize its new loading binding")
        let remounted = try XCTUnwrap(findWebView(in: host.view))
        XCTAssertTrue(remounted === webView)
        XCTAssertFalse(remounted.navigationDelegate === oldCoordinator)
        XCTAssertTrue(remounted.uiDelegate === remounted.navigationDelegate)
        XCTAssertTrue((remounted.navigationDelegate as? AccrueWebView.Coordinator)?.webView === remounted)
        _ = try await javaScript("window.webkit.messageHandlers.AccrueWallet.postMessage('remounted'); true", in: webView)
        try await eventually { self.model.events.contains("42:remounted") }
        let currentToken = try await javaScript("window.documentToken", in: webView) as? String
        XCTAssertEqual(currentToken, token)
        XCTAssertEqual(server.requests.count, 1)
        oldCoordinator?.webView(webView, didStartProvisionalNavigation: nil)
        try await settle()
        XCTAssertFalse(previousModel.isLoading, "A detached coordinator must ignore queued navigation callbacks")
        XCTAssertFalse(model.isLoading)
    }

    func testCurrentCallbackAndContextRefreshWithoutNavigation() async throws {
        model.context = AccrueContextData()
        model.context?.updateUserData(referenceId: "before", email: nil, phoneNumber: nil, additionalData: nil)
        let webView = try await mount()
        try await ready(webView)
        let integratorScript = WKUserScript(source: "window.integratorMarker = 'preserved';", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(integratorScript)
        model.revision = 7
        model.context = AccrueContextData()
        model.context?.updateUserData(referenceId: "after", email: nil, phoneNumber: nil, additionalData: nil)
        try await settle()
        _ = try await javaScript("window.webkit.messageHandlers.AccrueWallet.postMessage('updated'); true", in: webView)
        try await eventually { self.model.events.contains("7:updated") }
        try await eventuallyJS("window.AccrueWallet.contextData.userData.referenceId === 'after'", in: webView)
        XCTAssertEqual(server.requests.count, 1)
        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 2,
                       "Context updates must replace the SDK script and preserve the integrator's script")
        // A later document must receive the latest context at document start too.
        webView.reload()
        try await eventually { self.server.requests.count >= 2 }
        try await ready(webView)
        let initialReference = try await javaScript("window.initialReferenceId", in: webView) as? String
        XCTAssertEqual(initialReference, "after")
        let integratorMarker = try await javaScript("window.integratorMarker", in: webView) as? String
        XCTAssertEqual(integratorMarker, "preserved")
    }

    func testFailedInitialLoadRetriesOnlyAfterRemount() async throws {
        server.rejectRequests = true
        let webView = try await mount()
        try await eventually { !self.server.requests.isEmpty && !webView.isLoading }
        XCTAssertNil(webView.url, "The fixture must fail before a document commits")
        let failedRequestCount = server.requests.count
        try await eventually { !self.model.isLoading }

        // Native updates must not turn a failure into another automatic reload loop.
        for _ in 0..<3 {
            model.revision += 1
            try await settle()
        }
        XCTAssertEqual(server.requests.count, failedRequestCount)
        server.rejectRequests = false
        model.revision += 1
        try await settle()
        XCTAssertEqual(server.requests.count, failedRequestCount)

        model.visible = false
        try await settle()
        model.visible = true
        try await eventually { self.server.requests.count > failedRequestCount }
        XCTAssertTrue(findWebView(in: host.view) === webView)
        _ = try XCTUnwrap(webView.url, "Remounting must retry the failed initial destination")
        try await ready(webView)
        XCTAssertEqual(webView.url?.path, "/wallet/auth/pin")
        XCTAssertEqual(server.requests.count, failedRequestCount + 1)
        model.revision += 1
        try await settle()
        XCTAssertEqual(server.requests.count, failedRequestCount + 1)
    }

    func testFailedBrowserNavigationPreservesDocumentOnRemount() async throws {
        let webView = try await mount()
        try await ready(webView)
        let token = try await javaScript("window.documentToken", in: webView) as? String
        server.rejectRequests = true
        _ = try await javaScript("location.href = '/auth-return'; true", in: webView)
        try await eventually { self.server.requests.count > 1 && !webView.isLoading }
        let requestsAfterFailure = server.requests.count
        server.rejectRequests = false
        model.visible = false
        try await settle()
        model.visible = true
        try await settle()
        XCTAssertTrue(findWebView(in: host.view) === webView)
        XCTAssertEqual(server.requests.count, requestsAfterFailure)
        let currentToken = try await javaScript("window.documentToken", in: webView) as? String
        XCTAssertEqual(currentToken, token, "A failed browser navigation must not restart the native destination")
    }

    func testProcessRecoveryClearsFailedLoadBeforeRemount() async throws {
        server.rejectRequests = true
        let webView = try await mount()
        try await eventually { !self.server.requests.isEmpty && !webView.isLoading }
        try await eventually { !self.model.isLoading }
        let failedRequestCount = server.requests.count
        server.rejectRequests = false
        let coordinator = try XCTUnwrap(webView.navigationDelegate as? AccrueWebView.Coordinator)
        coordinator.webViewWebContentProcessDidTerminate(webView)
        try await eventually { self.server.requests.count > failedRequestCount }
        try await ready(webView)
        let token = try await javaScript("window.documentToken", in: webView) as? String
        model.visible = false
        try await settle()
        model.visible = true
        try await settle()
        XCTAssertEqual(server.requests.count, failedRequestCount + 1)
        let currentToken = try await javaScript("window.documentToken", in: webView) as? String
        XCTAssertEqual(currentToken, token, "Successful explicit recovery must clear the pending remount retry")
    }

    func testContextReplacementPreservesDependentStartupScriptOrder() async throws {
        model.context = AccrueContextData()
        model.context?.updateUserData(referenceId: "before", email: nil, phoneNumber: nil, additionalData: nil)
        let webView = try await mount()
        try await ready(webView)
        let controller = webView.configuration.userContentController
        controller.addUserScript(WKUserScript(source: """
            window.startupReference = window.AccrueWallet?.contextData?.userData?.referenceId ?? 'missing';
            window.integrationOrder = ['first'];
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: "window.integrationOrder.push('second');",
                                              injectionTime: .atDocumentStart, forMainFrameOnly: true))
        for reference in ["intermediate", "after"] {
            let context = AccrueContextData()
            context.updateUserData(referenceId: reference, email: nil, phoneNumber: nil, additionalData: nil)
            model.context = context
            try await settle()
        }
        XCTAssertEqual(controller.userScripts.count, 3)
        XCTAssertEqual(server.requests.count, 1)
        webView.reload()
        try await eventually { self.server.requests.count == 2 }
        try await ready(webView)
        let startupReference = try await javaScript("window.startupReference", in: webView) as? String
        let integrationOrder = try await javaScript("window.integrationOrder.join(',')", in: webView) as? String
        XCTAssertEqual(startupReference, "after", "Dependent scripts must run after the latest SDK context")
        XCTAssertEqual(integrationOrder, "first,second")
    }

    func testHTTPRedirectAndAuthNavigationAreNotOverridden() async throws {
        model.url = server.url("/redirect")
        let webView = try await mount()
        try await ready(webView)
        _ = try await javaScript("location.href = '/auth-return'; true", in: webView)
        try await eventually { webView.url?.path == "/auth-return" && !webView.isLoading }
        model.revision += 1
        try await settle()
        XCTAssertEqual(webView.url?.path, "/auth-return")
        XCTAssertEqual(server.requests.filter { $0 == "/redirect" }.count, 1)
        XCTAssertEqual(server.requests.filter { $0 == "/wallet/boot" }.count, 1)
        XCTAssertEqual(server.requests.filter { $0 == "/auth-return" }.count, 1)
    }

    func testExplicitReloadAndProcessRecoveryRemainPossible() async throws {
        let webView = try await mount()
        try await ready(webView)
        webView.reload()
        try await eventually { self.server.requests.count >= 2 }
        try await ready(webView)
        let coordinator = try XCTUnwrap(webView.navigationDelegate as? AccrueWebView.Coordinator)
        coordinator.webViewWebContentProcessDidTerminate(webView)
        try await eventually { self.server.requests.count >= 3 }
        try await ready(webView)
        model.revision += 1
        try await settle()
        XCTAssertEqual(server.requests, ["/wallet/boot", "/wallet/auth/pin", "/wallet/auth/pin"])
    }

    func testCleanupCreatesFreshWebViewForSameDestination() async throws {
        let webView = try await mount()
        try await ready(webView)
        model.visible = false
        try await settle()
        AccrueWebView.cleanup()
        model.visible = true
        try await settle()
        let fresh = try XCTUnwrap(findWebView(in: host.view))
        XCTAssertFalse(fresh === webView)
        try await ready(fresh)
        XCTAssertEqual(server.requests.filter { $0 == "/wallet/boot" }.count, 2)
    }

    private func mount() async throws -> WKWebView {
        host = UIHostingController(rootView: WalletTestHost(model: model))
        window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await eventually { self.findWebView(in: self.host.view) != nil }
        return try XCTUnwrap(findWebView(in: host.view))
    }

    private func ready(_ webView: WKWebView) async throws {
        try await eventually { !webView.isLoading && webView.url != nil }
        try await eventuallyJS("window.documentToken !== undefined", in: webView)
        try await settle()
    }

    private func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        return view.subviews.lazy.compactMap { self.findWebView(in: $0) }.first
    }

    private func settle() async throws { try await Task.sleep(nanoseconds: 200_000_000) }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(8)
        while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertTrue(condition(), "Condition did not become true", file: file, line: line)
    }

    private func eventuallyJS(_ script: String, in webView: WKWebView, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if (try? await javaScript(script, in: webView)) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("JavaScript condition did not become true: \(script)", file: file, line: line)
    }

    private func javaScript(_ script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result) }
            }
        }
    }
}

@MainActor
private final class WalletTestModel: ObservableObject {
    @Published var url: URL
    @Published var isLoading = false
    @Published var visible = true
    @Published var revision = 0
    @Published var context: AccrueContextData?
    var events: [String] = []
    init(url: URL) { self.url = url }
}

private struct WalletTestHost: View {
    @ObservedObject var model: WalletTestModel
    var body: some View {
        if model.visible {
            let revision = model.revision
            AccrueWebView(url: model.url, contextData: model.context, onAction: { event in
                model.events.append("\(revision):\(event)")
            }, isLoading: $model.isLoading)
        }
    }
}

/// No external resources: every request, redirect and auth page stays on 127.0.0.1.
private final class WalletHTTPFixture: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "wallet-test-http")
    private let lock = NSLock()
    private var recordedRequests: [String] = []
    private var listeningPort: UInt16?
    private var shouldRejectRequests = false
    var rejectRequests: Bool {
        get { lock.lock(); defer { lock.unlock() }; return shouldRejectRequests }
        set { lock.lock(); defer { lock.unlock() }; shouldRejectRequests = newValue }
    }
    var requests: [String] { lock.lock(); defer { lock.unlock() }; return recordedRequests }
    var port: UInt16? { lock.lock(); defer { lock.unlock() }; return listeningPort }

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    func url(_ path: String) -> URL { URL(string: "http://127.0.0.1:\(port!)\(path)")! }
    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self, case .ready = state else { return }
            self.lock.lock()
            self.listeningPort = self.listener.port?.rawValue
            self.lock.unlock()
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receive(connection, accumulated: Data())
        }
        listener.start(queue: queue)
    }
    func stop() { listener.cancel() }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, error in
            guard let self, let data, error == nil else { connection.cancel(); return }
            let buffer = accumulated + data
            let request = String(decoding: buffer, as: UTF8.self)
            guard request.contains("\r\n\r\n") else {
                if done { connection.cancel() } else { self.receive(connection, accumulated: buffer) }
                return
            }
            let path = String(request.split(separator: " ")[1])
            self.lock.lock()
            self.recordedRequests.append(path)
            let rejectRequest = self.shouldRejectRequests
            self.lock.unlock()
            if rejectRequest {
                connection.cancel()
                return
            }
            let response: String
            if path == "/redirect" {
                response = "HTTP/1.1 302 Found\r\nLocation: /wallet/boot\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            } else {
                let html = """
                <!doctype html><html><body>Local wallet fixture<script>
                window.documentToken = Math.random().toString();
                window.initialReferenceId = window.AccrueWallet?.contextData?.userData?.referenceId;
                window.homeCalls = 0;
                window.__GO_TO_HOME_SCREEN = function() { window.homeCalls++; };
                window.__SET_IOS_CONTEXT_DATA = function(data) { window.latestContext = data; };
                if (location.pathname === '/wallet/boot') history.replaceState({}, '', '/wallet/auth/pin' + location.search);
                </script></body></html>
                """
                response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nCache-Control: no-store\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            }
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
#endif
