import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderSync
@testable import ReaderUI

@MainActor
struct AutomaticRefreshTests {
    @Test func `Fenster teilen Aktualisierung und respektieren das Zeitfenster`() async throws {
        let store = try ReaderStore(inMemory: true)
        let account = ReaderAccount(serverURL: try #require(URL(string: "https://refresh.test/api/greader.php")), username: "test")
        try await store.saveAccount(account)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshProtocol.self]
        let client = FreshRSSClient(repository: store, credentials: RefreshCredentials(), session: URLSession(configuration: configuration))
        let services = ReaderServices(repository: store, client: client)
        RefreshProtocol.counts.reset()
        async let first: Void = services.refreshIfNeeded()
        async let second: Void = services.refreshIfNeeded()
        _ = try await (first, second)
        try await services.refreshIfNeeded()
        #expect(RefreshProtocol.counts.value == 1)
        try await services.refreshIfNeeded(force: true)
        #expect(RefreshProtocol.counts.value == 2)
    }
}

private actor RefreshCredentials: CredentialStore {
    func password(accountID: UUID) -> String? { "test-api-password" }
    func savePassword(_ password: String, accountID: UUID) { }
    func removePassword(accountID: UUID) { }
}

private final class RefreshCounts: @unchecked Sendable {
    private let lock = NSLock()
    private var subscriptions = 0
    var value: Int { lock.withLock { subscriptions } }
    func increment() { lock.withLock { subscriptions += 1 } }
    func reset() { lock.withLock { subscriptions = 0 } }
}

private final class RefreshProtocol: URLProtocol, @unchecked Sendable {
    static let counts = RefreshCounts()
    override static func canInit(with request: URLRequest) -> Bool { request.url?.host == "refresh.test" }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else { return }
        let body: String
        if url.path.hasSuffix("ClientLogin") { body = "SID=test\nAuth=test-auth\n" } else if url.path.hasSuffix("subscription/list") { Self.counts.increment(); body = #"{"subscriptions":[]}"# } else if url.path.hasSuffix("tag/list") { body = #"{"tags":[]}"# } else if url.path.hasSuffix("stream/items/ids") { body = #"{"itemRefs":[]}"# } else if url.path.hasSuffix("token") { body = "test-token" } else { body = "{}" }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
