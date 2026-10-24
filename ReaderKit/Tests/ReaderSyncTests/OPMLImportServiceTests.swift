import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
@testable import ReaderSync

struct OPMLImportServiceTests {
    @Test func `Verschachtelte gleichnamige Ordner und Homepage bleiben nach bestätigtem Import erhalten`() async throws {
        let fixture = try OPMLFixture()
        try await fixture.repository.saveAccount(fixture.account)
        #expect(try await fixture.importer.importDocument(Self.nested, account: fixture.account) == 2)
        let feeds = try await fixture.repository.feeds()
        #expect(Set(feeds.flatMap(\.folderIDs)) == ["user/-/label/A/News", "user/-/label/B/News"])
        let settings = try await fixture.repository.preferences()
        let first = try #require(settings.first { $0.importedFolderPath == ["A", "News"] })
        #expect(first.importedHomePageURL?.absoluteString == "https://source.test/home-a")
        #expect(feeds.first { $0.id == first.id }?.homePageURL?.absoluteString == "https://source.test/home-a")
        #expect(first.importedFeedURL?.absoluteString == "https://source.test/feed-a")
        #expect(feeds.first { $0.id == first.id }?.url.absoluteString == "https://canonical.test/feed/1")
        #expect(await fixture.server.quickAdds == 2)
    }

    @Test func `Wiederholungsimport nutzt bestätigte Redirect-ID und erhält lokale KI-Einstellungen`() async throws {
        let fixture = try OPMLFixture()
        _ = try await fixture.importer.importDocument(Self.nested, account: fixture.account)
        var settings = try #require(try await fixture.repository.preferences().first)
        settings.mode = .digest
        settings.cloudAllowed = true
        settings.timeZoneID = "Europe/Vienna"
        try await fixture.repository.savePreferences(settings)
        _ = try await fixture.importer.importDocument(Self.nested, account: fixture.account)
        #expect(await fixture.server.quickAdds == 2)
        #expect(try await fixture.repository.feeds().count == 2)
        let restored = try #require(try await fixture.repository.preferences().first { $0.id == settings.id })
        #expect(restored.mode == .digest)
        #expect(restored.cloudAllowed)
        #expect(restored.timeZoneID == "Europe/Vienna")
        #expect(restored.importedHomePageURL == settings.importedHomePageURL)
        #expect(restored.importedFolderPath == settings.importedFolderPath)
    }

    @Test func `Widersprüchliche Duplikate werden vor allen Serverwrites abgelehnt`() async throws {
        let fixture = try OPMLFixture()
        let data = Data("""
        <opml version="2.0"><body><outline xmlUrl="https://source.test/first"/><outline text="A"><outline xmlUrl="https://source.test/conflict"/></outline><outline text="B"><outline xmlUrl="https://source.test/conflict"/></outline></body></opml>
        """.utf8)
        await #expect(throws: (any Error).self) { try await fixture.importer.importDocument(data, account: fixture.account) }
        #expect(await fixture.server.requestCount == 0)
        #expect(try await fixture.repository.feeds().isEmpty)
    }

    @Test func `Identische Duplikate werden einmal importiert`() async throws {
        let fixture = try OPMLFixture()
        let data = Data("""
        <opml version="2.0"><body><outline text="A"><outline title="Feed" xmlUrl="https://source.test/feed"/><outline title="Feed" xmlUrl="https://source.test/feed" htmlUrl="https://source.test/home"/></outline></body></opml>
        """.utf8)
        #expect(try await fixture.importer.importDocument(data, account: fixture.account) == 1)
        #expect(await fixture.server.quickAdds == 1)
        #expect(try await fixture.repository.feeds().first?.homePageURL?.absoluteString == "https://source.test/home")
    }

    @Test func `Ungültige spätere Feedadresse verhindert auch frühere Serverwrites`() async throws {
        let fixture = try OPMLFixture()
        let data = Data("<opml><body><outline xmlUrl='https://source.test/valid'/><outline xmlUrl='http:relative'/></body></opml>".utf8)
        await #expect(throws: (any Error).self) { try await fixture.importer.importDocument(data, account: fixture.account) }
        #expect(await fixture.server.requestCount == 0)
    }

    @Test func `Bestehendes Abo wird bestätigt verschoben und nicht nochmals angelegt`() async throws {
        let fixture = try OPMLFixture()
        let before = Data("<opml><body><outline text='A'><outline text='News'><outline xmlUrl='https://source.test/feed'/></outline></outline></body></opml>".utf8)
        let after = Data("<opml><body><outline text='B'><outline text='News'><outline xmlUrl='https://source.test/feed'/></outline></outline></body></opml>".utf8)
        _ = try await fixture.importer.importDocument(before, account: fixture.account)
        _ = try await fixture.importer.importDocument(after, account: fixture.account)
        #expect(await fixture.server.quickAdds == 1)
        #expect(await fixture.server.moves == 1)
        #expect(try await fixture.repository.feeds().first?.folderIDs == ["user/-/label/B/News"])
        #expect(try await fixture.repository.preferences().first?.importedFolderPath == ["B", "News"])
    }

    @Test func `Abgelehnte Ordnerzuordnung speichert keine vermeintlich bestätigten Importmetadaten`() async throws {
        let fixture = try OPMLFixture()
        await fixture.server.rejectMutations()
        await #expect(throws: ReaderError.server(500)) {
            try await fixture.importer.importDocument(Self.nested, account: fixture.account)
        }
        #expect(try await fixture.repository.preferences().isEmpty)
        #expect(try await fixture.repository.feeds().isEmpty)
    }

    @Test(.timeLimit(.minutes(1))) func `Import überschreibt keine während der Serverantwort geänderte KI-Freigabe`() async throws {
        let fixture = try OPMLFixture()
        let before = Data("<opml><body><outline text='A'><outline xmlUrl='https://source.test/feed'/></outline></body></opml>".utf8)
        let after = Data("<opml><body><outline text='B'><outline xmlUrl='https://source.test/feed'/></outline></body></opml>".utf8)
        _ = try await fixture.importer.importDocument(before, account: fixture.account)
        let gate = ImportRequestGate()
        await fixture.server.setMoveGate(gate)
        let importing = Task { try await fixture.importer.importDocument(after, account: fixture.account) }
        await gate.waitUntilEntered()
        var settings = try #require(try await fixture.repository.preferences().first)
        settings.mode = .digest
        settings.cloudAllowed = true
        settings.timeZoneID = "Europe/Vienna"
        try await fixture.repository.savePreferences(settings)
        await gate.open()
        _ = try await importing.value
        let restored = try #require(try await fixture.repository.preferences().first)
        #expect(restored.mode == .digest)
        #expect(restored.cloudAllowed)
        #expect(restored.timeZoneID == "Europe/Vienna")
        #expect(restored.importedFolderPath == ["B"])
    }

    private static let nested = Data("""
    <?xml version="1.0"?><opml version="2.0"><body>
      <outline text="A"><outline text="News"><outline title="Feed A" xmlUrl="https://source.test/feed-a" htmlUrl="https://source.test/home-a"/></outline></outline>
      <outline text="B"><outline text="News"><outline title="Feed B" xmlUrl="https://source.test/feed-b" htmlUrl="https://source.test/home-b"/></outline></outline>
    </body></opml>
    """.utf8)
}

private final class OPMLFixture: @unchecked Sendable {
    let repository: ReaderStore
    let server = OPMLTestServer()
    let account: ReaderAccount
    let importer: OPMLImportService
    private let session: URLSession
    private let host: String
    init() throws {
        repository = try ReaderStore(inMemory: true)
        host = UUID().uuidString.lowercased() + ".test"
        account = ReaderAccount(serverURL: try #require(URL(string: "https://" + host)), username: "test")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        let client = FreshRSSClient(repository: repository, credentials: OPMLTestCredentials(), session: session)
        importer = OPMLImportService(repository: repository, client: client)
        let server = server
        MockURLProtocol.register(host: host) { request in try await server.respond(request) }
    }
    deinit { session.invalidateAndCancel(); MockURLProtocol.unregister(host: host) }
}

private actor OPMLTestCredentials: CredentialStore {
    func password(accountID: UUID) -> String? { "test" }
    func savePassword(_ password: String, accountID: UUID) {}
    func removePassword(accountID: UUID) {}
}

private actor OPMLTestServer {
    struct RemoteFeed {
        let id: String
        let url: String
        var title: String
        var folders: [String]
    }
    private var feeds: [RemoteFeed] = []
    private var reject = false
    private var moveGate: ImportRequestGate?
    var requestCount = 0
    var quickAdds = 0
    var moves = 0
    func rejectMutations() { reject = true }
    func setMoveGate(_ gate: ImportRequestGate) { moveGate = gate }
    func respond(_ request: URLRequest) async throws -> (Int, Data) {
        requestCount += 1
        let path = try #require(request.url?.path)
        var fields: [String: String] = [:]
        if let body = request.httpBody, let encoded = String(data: body, encoding: .utf8) {
            var parts = URLComponents()
            parts.percentEncodedQuery = encoded
            for item in parts.queryItems ?? [] { fields[item.name] = item.value }
        }
        if path.hasSuffix("ClientLogin") { return (200, Data("Auth=token\n".utf8)) }
        if path.hasSuffix("/token") { return (200, Data("write-token".utf8)) }
        if path.hasSuffix("/subscription/quickadd") {
            _ = try #require(fields["quickadd"])
            quickAdds += 1
            let id = "feed/\(quickAdds)"
            feeds.append(RemoteFeed(id: id, url: "https://canonical.test/\(id)", title: "Servername", folders: []))
            return try json(["numResults": 1, "streamId": id])
        }
        if path.hasSuffix("/subscription/edit") {
            if reject { return (500, Data()) }
            let id = try #require(fields["s"])
            let index = try #require(feeds.firstIndex { $0.id == id })
            if fields["r"] != nil, let moveGate { await moveGate.pause() }
            if let title = fields["t"] { feeds[index].title = title }
            if let old = fields["r"] { feeds[index].folders.removeAll { $0 == old }; moves += 1 }
            if let folder = fields["a"] { feeds[index].folders.append(folder) }
            return (200, Data("OK".utf8))
        }
        if path.hasSuffix("/subscription/list") {
            let subscriptions: [[String: Any]] = feeds.map { feed in
                ["id": feed.id, "title": feed.title, "url": feed.url, "categories": feed.folders.map { ["id": $0] }]
            }
            return try json(["subscriptions": subscriptions])
        }
        if path.hasSuffix("/tag/list") { return try json(["tags": Set(feeds.flatMap(\.folders)).sorted().map { ["id": $0] }]) }
        if path.hasSuffix("/stream/items/ids") { return try json(["itemRefs": []]) }
        throw ReaderError.invalidResponse
    }

    private func json(_ value: [String: Any]) throws -> (Int, Data) { (200, try JSONSerialization.data(withJSONObject: value)) }
}

private actor ImportRequestGate {
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
