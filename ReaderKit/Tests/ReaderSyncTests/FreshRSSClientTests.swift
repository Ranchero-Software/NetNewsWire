import Foundation
import Synchronization
import Testing
import ReaderDomain
@testable import ReaderSync

struct FreshRSSClientTests {
    @Test(arguments: ["0", "1", "9223372036854775807", "-9223372036854775808", "-1"])
    func `Artikel-IDs überstehen die Reader-API-Kodierung`(id: String) throws {
        #expect(try ReaderItemID.canonical(ReaderItemID.longForm(id)) == id)
    }

    @Test func `Installationsunterordner und expliziter API-Pfad bleiben erhalten`() throws {
        let root = try #require(URL(string: "https://example.test/rss"))
        let api = try #require(URL(string: "https://example.test/rss/api/greader.php"))
        #expect(try FreshRSSClient.endpoint(for: root) == api)
        #expect(try FreshRSSClient.endpoint(for: api) == api)
        #expect(throws: ReaderError.invalidURL) {
            try FreshRSSClient.endpoint(for: #require(URL(string: "file:///tmp/rss")))
        }
    }

    @Test func `Refresh wartet auf alle Seiten und behält alte Veröffentlichungen`() async throws {
        let fixture = try Fixture()
        try await fixture.client.refresh(account: fixture.account)
        let snapshots = await fixture.repository.snapshots
        let snapshot = try #require(snapshots.first)
        #expect(snapshots.count == 1)
        #expect(Set(snapshot.articles.map { $0.id.remoteID }) == ["1", "2"])
        #expect(snapshot.unreadIDs == ["1"])
        #expect(snapshot.starredIDs == ["2"])
        #expect(snapshot.articles.first?.datePublished?.timeIntervalSince1970 == 946684800)
        #expect(snapshot.articles.first?.dateArrived.timeIntervalSince1970 == 1792830000)
        #expect(snapshot.feeds.first?.homePageURL?.absoluteString == "https://news.test")
        let calls = await fixture.server.calls
        #expect(calls.allSatisfy { $0.query["ot"] == nil })
        #expect(calls.contains { $0.query["c"] == "next" })
        #expect(calls.filter { !$0.path.hasSuffix("ClientLogin") }.allSatisfy { $0.auth == "GoogleLogin auth=auth==" })
        let login = try #require(calls.first { $0.path.hasSuffix("ClientLogin") })
        #expect(login.fields["Email"] == ["mat+test"])
        #expect(login.fields["Passwd"] == ["a&b=c"])
    }

    @Test func `Fehlgeschlagener Ungelesenabruf verändert keinen lokalen Snapshot`() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.unread)
        await #expect(throws: ReaderError.server(503)) { try await fixture.client.refresh(account: fixture.account) }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test func `HTTP-Erfolg mit Fehlertext bestätigt keine Statusänderung`() async throws {
        let fixture = try Fixture()
        let change = PendingChange(article: ArticleKey(accountID: fixture.account.id, remoteID: "1"), field: .read, value: true)
        await fixture.repository.replacePending(change)
        await fixture.server.setFailure(.writeBody)
        await #expect(throws: ReaderError.invalidResponse) { try await fixture.client.flush(account: fixture.account) }
        #expect(await fixture.repository.pending == [change])
    }

    @Test func `Abgelehnte Umbenennung wird nicht lokal als Erfolg übernommen`() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.mutation)
        await #expect(throws: ReaderError.server(500)) {
            try await fixture.client.renameFeed(account: fixture.account, feedID: "feed/1", title: "Neuer Name")
        }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test func `Fehlender Artikelinhalt verhindert einen unvollständigen Commit`() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.missingContent)
        await #expect(throws: (any Error).self) { try await fixture.client.refresh(account: fixture.account) }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test func `Wiederholte Continuation wird als Fehler statt Endlosschleife behandelt`() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.continuationLoop)
        await #expect(throws: ReaderError.invalidResponse) { try await fixture.client.refresh(account: fixture.account) }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test func `Veraltetes Schreibtoken wird einmal erneuert`() async throws {
        let fixture = try Fixture()
        let change = PendingChange(article: ArticleKey(accountID: fixture.account.id, remoteID: "1"), field: .starred, value: true)
        await fixture.repository.replacePending(change)
        await fixture.server.setFailure(.expiredWriteToken)
        try await fixture.client.flush(account: fixture.account)
        #expect(await fixture.repository.pending.isEmpty)
        #expect(await fixture.server.tokenRequests == 2)
    }

    @Test(.timeLimit(.minutes(1))) func `Überlappende Sends bestätigen ausschließlich ihre eigenen Revisionen`() async throws {
        let fixture = try Fixture()
        let key = ArticleKey(accountID: fixture.account.id, remoteID: "1")
        let old = PendingChange(article: key, field: .read, value: true)
        let newer = PendingChange(article: key, field: .read, value: false)
        await fixture.repository.replacePending(old)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let first = Task { try await fixture.client.flush(account: fixture.account) }
        await gate.waitUntilEntered()
        await fixture.repository.replacePending(newer)
        await fixture.server.setFailure(.secondWrite)
        let second = Task { try await fixture.client.flush(account: fixture.account) }
        await gate.open()
        try await first.value
        await #expect(throws: ReaderError.server(500)) { try await second.value }
        #expect(await fixture.repository.pending == [newer])
        let writes = await fixture.server.calls.filter { $0.path.hasSuffix("/edit-tag") }
        #expect(writes.count == 2)
        #expect(writes[0].fields["a"] == ["user/-/state/com.google/read"])
        #expect(writes[1].fields["r"] == ["user/-/state/com.google/read"])
    }

    @Test func `Leere autoritative Ordnerliste wird weitergegeben`() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.emptyFolders)
        try await fixture.client.refresh(account: fixture.account)
        #expect(await fixture.repository.snapshots.first?.folders.isEmpty == true)
        #expect(await fixture.repository.snapshots.first?.feeds.first?.folderIDs.isEmpty == true)
    }
}

private final class Fixture: @unchecked Sendable {
    let account: ReaderAccount
    let repository = TestRepository()
    let server = TestServer()
    let client: FreshRSSClient
    private let host: String
    private let session: URLSession

    init() throws {
        host = UUID().uuidString.lowercased() + ".test"
        let url = try #require(URL(string: "https://" + host + "/rss"))
        account = ReaderAccount(serverURL: url, username: "mat+test")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = FreshRSSClient(repository: repository, credentials: TestCredentials(), session: session)
        let server = server
        MockURLProtocol.register(host: host) { request in try await server.respond(request) }
    }

    deinit {
        session.invalidateAndCancel()
        MockURLProtocol.unregister(host: host)
    }
}

private actor TestCredentials: CredentialStore {
    func password(accountID: UUID) -> String? { "a&b=c" }
    func savePassword(_ password: String, accountID: UUID) {}
    func removePassword(accountID: UUID) {}
}

private actor TestRepository: ReaderRepository {
    var snapshots: [RefreshSnapshot] = []
    var pending: [PendingChange] = []
    func replacePending(_ change: PendingChange) { pending = [change] }
    func accounts() -> [ReaderAccount] { [] }
    func saveAccount(_ account: ReaderAccount) {}
    func feeds() -> [FeedSnapshot] { [] }
    func folders() -> [FolderSnapshot] { [] }
    func articles(_ query: ArticleQuery) -> [ArticleSnapshot] { [] }
    func applyRefresh(_ snapshot: RefreshSnapshot) { snapshots.append(snapshot) }
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) {}
    func pendingChanges(accountID: UUID) -> [PendingChange] { pending.filter { $0.article.accountID == accountID } }
    func acknowledge(_ changes: [PendingChange]) {
        let ids = Set(changes.map(\.id))
        pending.removeAll { ids.contains($0.id) }
    }
    func preferences() -> [FeedPreferences] { [] }
    func savePreferences(_ preferences: FeedPreferences) {}
    func digests() -> [DigestSnapshot] { [] }
    func saveDigest(_ digest: DigestSnapshot) {}
    func updateContent(_ key: ArticleKey, html: String, text: String) {}
}

private struct RequestCall: Sendable {
    let path: String
    let query: [String: String]
    let fields: [String: [String]]
    let auth: String?
}

private actor RequestGate {
    private var entered = false
    private var observers: [CheckedContinuation<Void, Never>] = []
    private var blocked: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true
        observers.forEach { $0.resume() }
        observers.removeAll()
        await withCheckedContinuation { blocked = $0 }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func open() { blocked?.resume(); blocked = nil }
}

private actor TestServer {
    enum Failure { case unread, mutation, writeBody, missingContent, continuationLoop, expiredWriteToken, secondWrite, emptyFolders }
    private var failure: Failure?
    private var gate: RequestGate?
    private var writes = 0
    var tokenRequests = 0
    var calls: [RequestCall] = []
    func setFailure(_ value: Failure) { failure = value }
    func setWriteGate(_ value: RequestGate) { gate = value }

    func respond(_ request: URLRequest) async throws -> (Int, Data) {
        let url = try #require(request.url)
        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, latest in latest })
        var fields: [String: [String]] = [:]
        if let body = request.httpBody, let encoded = String(data: body, encoding: .utf8) {
            var parts = URLComponents()
            parts.percentEncodedQuery = encoded
            for item in parts.queryItems ?? [] { fields[item.name, default: []].append(item.value ?? "") }
        }
        calls.append(RequestCall(path: path, query: query, fields: fields, auth: request.value(forHTTPHeaderField: "Authorization")))
        if path.hasSuffix("ClientLogin") { return data("SID=ignored\nAuth=auth==\n") }
        if path.hasSuffix("/token") { tokenRequests += 1; return data("write-\(tokenRequests)\n") }
        if path.hasSuffix("/subscription/list") {
            let categories = failure == .emptyFolders ? "[]" : "[{\"id\":\"user/-/label/News\"}]"
            return data("{\"subscriptions\":[{\"id\":\"feed/1\",\"title\":\"News\",\"url\":\"https://news.test/feed\",\"htmlUrl\":\"https://news.test\",\"categories\":\(categories)}]}")
        }
        if path.hasSuffix("/tag/list") {
            return data(failure == .emptyFolders ? "{\"tags\":[]}" : "{\"tags\":[{\"id\":\"user/-/label/News\"}]}")
        }
        if path.hasSuffix("/stream/items/ids") {
            if query["xt"] != nil {
                if failure == .unread { return data("temporarily unavailable", status: 503) }
                return data("{\"itemRefs\":[{\"id\":\"1\"}]}")
            }
            if query["s"] == "user/-/state/com.google/starred" { return data("{\"itemRefs\":[{\"id\":\"2\"}]}") }
            if query["c"] == "next", failure != .continuationLoop { return data("{\"itemRefs\":[{\"id\":\"2\"}]}") }
            return data("{\"itemRefs\":[{\"id\":\"1\"}],\"continuation\":\"next\"}")
        }
        if path.hasSuffix("/stream/items/contents") {
            if failure == .missingContent { return data("{\"items\":[]}") }
            return data("""
            {"items":[{"id":"tag:google.com,2005:reader/item/0000000000000001","title":"Alter Beitrag","summary":{"content":"<p>Text &amp; Inhalt</p>"},"origin":{"streamId":"feed/1"},"published":946684800,"crawlTimeMsec":"1792830000000"},{"id":"tag:google.com,2005:reader/item/0000000000000002","title":"Zweiter Beitrag","summary":{"content":"Text"},"origin":{"streamId":"feed/1"}}]}
            """)
        }
        if path.hasSuffix("/edit-tag") {
            writes += 1
            let current = writes
            if current == 1, let gate { await gate.pause() }
            if failure == .secondWrite, current == 2 { return data("failure", status: 500) }
            if failure == .writeBody { return data("Error=notApplied") }
            if failure == .expiredWriteToken, fields["T"] == ["write-1"] { return data("expired", status: 403) }
            return data("OK")
        }
        if path.hasSuffix("/subscription/edit") { return data("failure", status: failure == .mutation ? 500 : 200) }
        throw ReaderError.invalidResponse
    }

    private func data(_ value: String, status: Int = 200) -> (Int, Data) { (status, Data(value.utf8)) }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Int, Data)
    private static let handlers = Mutex<[String: Handler]>([:])
    private let runningTask = Mutex<Task<Void, Never>?>(nil)
    static func register(host: String, handler: @escaping Handler) { handlers.withLock { $0[host] = handler } }
    static func unregister(host: String) { handlers.withLock { $0[host] = nil } }
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let handler = Self.handlers.withLock { $0[request.url?.host ?? ""] }
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            request.httpBody = body
        }
        let capturedRequest = request
        let task = Task {
            do {
                guard let handler, let url = capturedRequest.url else { throw ReaderError.invalidResponse }
                let (status, data) = try await handler(capturedRequest)
                try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
                    throw ReaderError.invalidResponse
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        runningTask.withLock { $0 = task }
    }
    override func stopLoading() { runningTask.withLock { $0?.cancel(); $0 = nil } }
}
