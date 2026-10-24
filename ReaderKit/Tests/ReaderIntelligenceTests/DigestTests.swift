import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderIntelligence

private struct FixtureGenerator: SummaryGenerator {
    var omitLast = false
    var invalid = false
    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        if invalid { return [DigestSection(title: "Falsch", text: "", sources: [ArticleKey(accountID: UUID(), remoteID: "wrong")])] }
        let sources = omitLast ? Array(articles.dropLast()) : articles
        return [DigestSection(title: "Angebote", text: "Belegte Übersicht", sources: sources.map(\.id))]
    }
}

private actor ControlledGenerator: SummaryGenerator {
    private var started = false
    private var starters: [CheckedContinuation<Void, Never>] = []
    private var blocked: CheckedContinuation<Void, Never>?
    private(set) var observedCloudPermission: Bool?

    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        throw ReaderError.invalidResponse
    }
    func summarize(_ articles: [ArticleSnapshot], cloudPermission: @escaping @Sendable () async throws -> Bool) async throws -> [DigestSection] {
        started = true
        for continuation in starters { continuation.resume() }
        starters.removeAll()
        await withCheckedContinuation { blocked = $0 }
        observedCloudPermission = try await cloudPermission()
        return [DigestSection(title: "Übersicht", text: "Belegt", sources: articles.map(\.id))]
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { starters.append($0) }
    }
    func release() { blocked?.resume(); blocked = nil }
}

struct DigestTests {
    private func fixture(count: Int = 2) async throws -> (ReaderStore, FeedSnapshot, [ArticleSnapshot]) {
        let store = try ReaderStore(inMemory: true)
        let account = UUID()
        let feed = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "feed/1"), title: "Preisjäger", url: try #require(URL(string: "https://example.org/rss")))
        let articles = (0..<count).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: account, remoteID: String(index)), feedID: feed.id.remoteID,
                title: "Angebot \(index)", text: String(repeating: "Quellentext ", count: 60),
                dateArrived: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)))
        }
        try await store.applyRefresh(RefreshSnapshot(accountID: account, feeds: [feed], folders: [], articles: articles,
            unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, timeZoneID: "Europe/Vienna"))
        return (store, feed, articles)
    }

    @Test func `Alle Quellen bleiben auch bei unvollständiger KI erreichbar`() async throws {
        let (store, feed, articles) = try await fixture(count: 250)
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(omitLast: true))
        let digests = try await coordinator.generate(feed: feed)
        #expect(Set(digests.flatMap(\.sources)) == Set(articles.map(\.id)))
        #expect(Set(digests.flatMap(\.sections).flatMap(\.sources)) == Set(articles.map(\.id)))
        #expect(digests.contains { $0.warning != nil })
    }

    @Test func `Abhaken gilt nur für die angezeigte Revision`() async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator())
        let old = try #require(try await coordinator.generate(feed: feed).first)
        let later = ArticleSnapshot(id: ArticleKey(accountID: feed.id.accountID, remoteID: "later"),
            feedID: feed.id.remoteID, title: "Neu", text: String(repeating: "Quellentext ", count: 60), dateArrived: articles[0].dateArrived)
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed], folders: [],
            articles: articles + [later], unreadIDs: Set((articles + [later]).map(\.id.remoteID)), starredIDs: []))
        _ = try await coordinator.generate(feed: feed)
        try await coordinator.markRead(old)
        #expect(try await store.article(later.id)?.read == false)
        #expect(try await store.article(articles[0].id)?.read == true)
    }

    @Test func `Ungültige KI-Quellen werden nicht gespeichert`() async throws {
        let (store, feed, _) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(invalid: true))
        await #expect(throws: ReaderError.invalidResponse) { try await coordinator.generate(feed: feed) }
        #expect(try await store.digests().isEmpty)
    }

    @Test func `Geänderter Quellentext erneuert eine Übersicht`() async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator())
        let before = try #require(try await coordinator.generate(feed: feed).first)
        var changed = articles
        changed[0].text = String(repeating: "Neuer Quellentext ", count: 60)
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed], folders: [], articles: changed,
            unreadIDs: Set(changed.map(\.id.remoteID)), starredIDs: []))
        let after = try #require(try await coordinator.generate(feed: feed).first)
        #expect(after.revision != before.revision)
        #expect(after.sourceFingerprint != before.sourceFingerprint)
    }

    @Test func `Widerrufene Cloudfreigabe gilt auch für laufende Arbeit`() async throws {
        let (store, feed, _) = try await fixture()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, cloudAllowed: true))
        let model = ControlledGenerator()
        let coordinator = DigestCoordinator(repository: store, generator: model)
        let generation = Task { try await coordinator.generate(feed: feed) }
        await model.waitUntilStarted()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, cloudAllowed: false))
        await model.release()
        _ = try await generation.value
        #expect(await model.observedCloudPermission == false)
    }

    @Test func `Modellantwort für inzwischen geänderte Quellen wird nicht gespeichert`() async throws {
        let (store, feed, articles) = try await fixture()
        let model = ControlledGenerator()
        let coordinator = DigestCoordinator(repository: store, generator: model)
        let generation = Task { try await coordinator.generate(feed: feed) }
        await model.waitUntilStarted()
        try await store.updateContent(articles[0].id, html: "Neuer Artikel", text: "Neu")
        await model.release()
        await #expect(throws: ReaderError.staleResult) { try await generation.value }
        #expect(try await store.digests().isEmpty)
    }

    @Test func `Geschlossenes Fenster bricht den besessenen Digestauftrag nicht ab`() async throws {
        let (store, feed, _) = try await fixture()
        let model = ControlledGenerator()
        let coordinator = DigestCoordinator(repository: store, generator: model)
        let window = Task { try await coordinator.generate(feed: feed) }
        await model.waitUntilStarted()
        window.cancel()
        await model.release()
        let result = try await window.value
        #expect(!result.isEmpty)
        #expect(try await store.digests().count == result.count)
    }
}
