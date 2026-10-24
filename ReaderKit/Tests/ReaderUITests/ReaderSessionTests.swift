import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
@testable import ReaderUI

@MainActor
struct ReaderSessionTests {
    private func fixture(count: Int = 3) async throws -> (ReaderStore, ReaderServices, FeedSnapshot, [ArticleSnapshot]) {
        let store = try ReaderStore(inMemory: true)
        let account = ReaderAccount(serverURL: try #require(URL(string: "https://example.test/api/greader.php")), username: "reader")
        try await store.saveAccount(account)
        let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "feed/1"), title: "Testfeed", url: account.serverURL)
        let articles = (0..<count).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "\(index)"), feedID: feed.id.remoteID,
                            title: "Artikel \(index)", text: "Inhalt \(index)", dateArrived: Date(timeIntervalSince1970: Double(index)))
        }
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: articles,
                                                    unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
        return (store, ReaderServices(repository: store), feed, articles)
    }

    @Test func `Fenster besitzen unabhängige Auswahl und Suche`() async throws {
        let (_, services, feed, _) = try await fixture()
        let a = ReaderSession(services: services)
        let b = ReaderSession(services: services)
        a.sidebarSelection = feed.id.id
        a.search = "Artikel 1"
        b.sidebarSelection = "all"
        await a.reload()
        await b.reload()
        #expect(a.articles.count == 1)
        #expect(b.articles.count == 3)
        #expect(b.search.isEmpty)
        a.showingAccount = true
        #expect(!b.showingAccount)
    }

    @Test func `Öffnen einer Übersicht verändert keinen Originalstatus`() async throws {
        let (store, services, feed, articles) = try await fixture()
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [], sources: articles.map(\.id))
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        session.selection = .digest(digest.id)
        await session.loadSources(digest)
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).count == 3)
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }

    @Test func `Nicht zusammengefasste Originale bleiben trotz Digestmodus sichtbar`() async throws {
        let (store, services, feed, articles) = try await fixture()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [], sources: [articles[0].id])
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.rows.count == 3)
        #expect(session.rows.contains { $0.id == .article(articles[1].id) })
        #expect(session.rows.contains { $0.id == .article(articles[2].id) })
    }

    @Test func `Quellen außerhalb der geladenen Seite bleiben erreichbar`() async throws {
        let (store, services, feed, articles) = try await fixture(count: 350)
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [], sources: articles.map(\.id))
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.articles.count == 200)
        await session.loadSources(digest)
        #expect(session.sourceArticles.count == 350)
        session.selection = .article(articles[0].id)
        await session.loadSelectedArticle()
        #expect(session.selectedArticle?.id == articles[0].id)
    }

    @Test func `Abhaken einer angezeigten Revision lässt neue Quellen ungelesen`() async throws {
        let (store, services, feed, articles) = try await fixture()
        let displayed = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                       sections: [], sources: [articles[0].id])
        var updated = displayed
        updated.sources = articles.map(\.id)
        updated.revision = UUID()
        try await store.saveDigest(updated)
        let session = ReaderSession(services: services)
        await session.setStatus(displayed.sources, field: .read, value: true)
        let unread = try await store.articles(ArticleQuery(unreadOnly: true))
        #expect(Set(unread.map(\.id)) == Set([articles[1].id, articles[2].id]))
    }

    @Test func `Pagination erreicht mehr als tausend Artikel`() async throws {
        let (_, services, _, _) = try await fixture(count: 1_210)
        let session = ReaderSession(services: services)
        await session.reload()
        for _ in 0..<6 { await session.loadMore() }
        #expect(session.articles.count == 1_210)
        #expect(!session.canLoadMore)
    }

    @Test func `Verspätete Antworten von A und B überschreiben C nicht`() async throws {
        let (store, _, feed, _) = try await fixture()
        let gate = QueryGate(accountID: feed.id.accountID)
        let repository = ScriptedRepository(base: store) { query in await gate.response(query.search) }
        let session = ReaderSession(services: ReaderServices(repository: repository))
        session.search = "A"
        let a = Task { await session.reload() }
        await gate.waitUntilStarted("A")
        session.search = "B"
        let b = Task { await session.reload() }
        await gate.waitUntilStarted("B")
        session.search = "C"
        let c = Task { await session.reload() }
        await gate.waitUntilStarted("C")
        await gate.release("C")
        await c.value
        #expect(session.articles.first?.title == "C")
        await gate.release("B")
        await gate.release("A")
        await a.value
        await b.value
        #expect(session.articles.first?.title == "C")
        #expect(session.rows.first?.title == "C")
    }

    @Test func `Überlappende Datenbankseiten ergeben keine doppelten Zeilen`() async throws {
        let (store, _, _, _) = try await fixture(count: 450)
        let repository = ScriptedRepository(base: store) { query in
            var page = try await store.articles(query)
            if query.offset == 0, let first = page.first { page[page.count - 1] = first }
            return page
        }
        let session = ReaderSession(services: ReaderServices(repository: repository))
        await session.reload()
        await session.loadMore()
        #expect(session.articles.count == 400)
        #expect(Set(session.rows.map(\.id)).count == session.rows.count)
    }

    @Test func `Aktualisierung ersetzt die angezeigte Digestrevision erst auf Wunsch`() async throws {
        let (store, services, feed, articles) = try await fixture()
        let original = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna", sections: [], sources: [articles[0].id])
        try await store.saveDigest(original)
        let session = ReaderSession(services: services)
        await session.reload()
        session.selection = .digest(original.id)
        var updated = original
        updated.revision = UUID()
        updated.sources = articles.map(\.id)
        try await store.saveDigest(updated)
        await session.reload()
        #expect(session.selectedDigest?.revision == original.revision)
        #expect(session.selectedDigest?.sources.count == 1)
        session.openLatestDigest()
        #expect(session.selectedDigest?.revision == updated.revision)
    }

    @Test func `Gebündelte Rohartikel verdrängen normale Feeds nicht aus der ersten Seite`() async throws {
        let (store, services, feed, articles) = try await fixture(count: 251)
        let normal = FeedSnapshot(id: FeedKey(accountID: feed.id.accountID, remoteID: "normal"), title: "Normal", url: feed.url)
        var oldest = articles[0]
        oldest.feedID = normal.id.remoteID
        var input = articles
        input[0] = oldest
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed, normal], folders: [], articles: input,
                                                    unreadIDs: Set(input.map(\.id.remoteID)), starredIDs: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        try await store.saveDigest(DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna", sections: [],
                                                  sources: Array(articles.dropFirst().map(\.id))))
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.rows.contains { $0.id == .article(oldest.id) })
        #expect(session.rows.count == 2)
    }
}

private actor QueryGate {
    let accountID: UUID
    var started: Set<String> = []
    var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    var responses: [String: CheckedContinuation<[ArticleSnapshot], Never>] = [:]

    init(accountID: UUID) { self.accountID = accountID }

    func response(_ search: String) async -> [ArticleSnapshot] {
        started.insert(search)
        waiters.removeValue(forKey: search)?.resume()
        return await withCheckedContinuation { responses[search] = $0 }
    }

    func waitUntilStarted(_ search: String) async {
        if started.contains(search) { return }
        await withCheckedContinuation { waiters[search] = $0 }
    }

    func release(_ search: String) {
        responses.removeValue(forKey: search)?.resume(returning: [ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: search), feedID: "feed/1", title: search)])
    }
}

private actor ScriptedRepository: ReaderRepository {
    let base: any ReaderRepository
    let query: @Sendable (ArticleQuery) async throws -> [ArticleSnapshot]
    init(base: any ReaderRepository, query: @escaping @Sendable (ArticleQuery) async throws -> [ArticleSnapshot]) { self.base = base; self.query = query }
    func accounts() async throws -> [ReaderAccount] { try await base.accounts() }
    func saveAccount(_ account: ReaderAccount) async throws { try await base.saveAccount(account) }
    func feeds() async throws -> [FeedSnapshot] { try await base.feeds() }
    func folders() async throws -> [FolderSnapshot] { try await base.folders() }
    func articles(_ query: ArticleQuery) async throws -> [ArticleSnapshot] { try await self.query(query) }
    func article(_ key: ArticleKey) async throws -> ArticleSnapshot? { try await base.article(key) }
    func applyRefresh(_ snapshot: RefreshSnapshot) async throws { try await base.applyRefresh(snapshot) }
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) async throws { try await base.setStatus(keys, field: field, value: value) }
    func pendingChanges(accountID: UUID) async throws -> [PendingChange] { try await base.pendingChanges(accountID: accountID) }
    func acknowledge(_ changes: [PendingChange]) async throws { try await base.acknowledge(changes) }
    func preferences() async throws -> [FeedPreferences] { try await base.preferences() }
    func savePreferences(_ preferences: FeedPreferences) async throws { try await base.savePreferences(preferences) }
    func digests() async throws -> [DigestSnapshot] { try await base.digests() }
    func saveDigest(_ digest: DigestSnapshot) async throws { try await base.saveDigest(digest) }
    func updateContent(_ key: ArticleKey, html: String, text: String) async throws { try await base.updateContent(key, html: html, text: text) }
}
