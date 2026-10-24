import Foundation
import Testing
import ReaderDomain
@testable import ReaderPersistence

struct ReaderStoreTests {
    private let accountID = UUID()
    private let fixtureURL: URL

    init() throws {
        fixtureURL = try #require(URL(string: "https://example.com/feed"))
    }

    private var feed: FeedSnapshot {
        FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/1"), title: "Nachrichten",
                     url: fixtureURL)
    }

    private func article(_ id: String = "1", title: String = "Titel", text: String = "Text",
                         read: Bool = false, starred: Bool = false, arrived: Date = Date(timeIntervalSince1970: 100)) -> ArticleSnapshot {
        ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: id), feedID: feed.id.remoteID,
                        title: title, text: text, dateArrived: arrived, read: read, starred: starred)
    }

    private func refresh(articles: [ArticleSnapshot], feeds: [FeedSnapshot]? = nil,
                         folders: [FolderSnapshot] = [], unread: Set<String> = ["1"],
                         starred: Set<String> = []) -> RefreshSnapshot {
        RefreshSnapshot(accountID: accountID, feeds: feeds ?? [feed], folders: folders,
                        articles: articles, unreadIDs: unread, starredIDs: starred)
    }

    @Test func `Alte Bestätigung lässt neuere Änderung ausstehend`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .read, value: true)
        let old = try await store.pendingChanges(accountID: accountID)
        try await store.setStatus([original.id], field: .read, value: false)
        try await store.acknowledge(old)
        let pending = try await store.pendingChanges(accountID: accountID)
        #expect(pending.count == 1)
        #expect(pending.first?.value == false)
        #expect(pending.first?.id != old.first?.id)
    }

    @Test func `Remoteabgleich schützt beide ausstehenden Statusrichtungen`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .read, value: false)
        try await store.setStatus([original.id], field: .starred, value: true)
        try await store.applyRefresh(refresh(articles: [], unread: []))
        let persisted = try #require(try await store.articles(ArticleQuery()).first)
        #expect(!persisted.read)
        #expect(persisted.starred)
        #expect(try await store.pendingChanges(accountID: accountID).count == 2)
    }

    @Test func `Doppelte Identitäten wählen eine vollständige Version und behalten Eingangstag`() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article(title: "A", text: "A")]))
        try await store.applyRefresh(refresh(articles: [
            article(title: "B", text: "A", arrived: Date(timeIntervalSince1970: 200)),
            article(title: "A", text: "B", arrived: Date(timeIntervalSince1970: 300))
        ]))
        let records = try await store.articles(ArticleQuery())
        #expect(records.count == 1)
        #expect(records.first?.title == "A")
        #expect(records.first?.text == "B")
        #expect(records.first?.dateArrived == Date(timeIntervalSince1970: 100))
    }

    @Test func `Leere autoritative Ordnerliste entfernt alte Zuordnungen`() async throws {
        let store = try ReaderStore(inMemory: true)
        let folder = FolderSnapshot(accountID: accountID, remoteID: "folder/1", title: "Ordner")
        var categorized = feed
        categorized.folderIDs = [folder.remoteID]
        try await store.applyRefresh(refresh(articles: [], feeds: [categorized], folders: [folder]))
        try await store.applyRefresh(refresh(articles: [], folders: []))
        #expect(try await store.folders().isEmpty)
        #expect(try await store.feeds().first?.folderIDs.isEmpty == true)
    }

    @Test func `Abbestellen behält Sterne und entfernt unmarkierte Artikel`() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article("1"), article("2")], unread: ["1", "2"], starred: ["1"]))
        try await store.applyRefresh(refresh(articles: [], feeds: [], unread: [], starred: []))
        let remaining = try await store.articles(ArticleQuery(starredOnly: true))
        #expect(remaining.map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery()).count == 1)
        #expect(try await store.feeds().isEmpty)
    }

    @Test func `Tagesübersicht hält ihre Originale nach Abbestellen erreichbar`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: original.dateArrived, timeZoneID: "Europe/Vienna",
                                    sections: [], sources: [original.id])
        try await store.saveDigest(digest)
        try await store.applyRefresh(refresh(articles: [], feeds: []))
        #expect(try await store.articles(ArticleQuery()).map(\.id) == [original.id])
    }

    @Test func `Fehlgeschlagene Sammeländerung rollt Status und Queue zurück`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let absent = ArticleKey(accountID: accountID, remoteID: "nicht-vorhanden")
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.setStatus([original.id, absent], field: .read, value: true)
        }
        #expect(try await store.articles(ArticleQuery()).first?.read == false)
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
    }

    @Test func `Suche und Pagination arbeiten mit normalisierten Texten`() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article("1", title: "Äpfel"), article("2", title: "Birnen")]))
        #expect(try await store.articles(ArticleQuery(search: "APFEL")).map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery(offset: 1, limit: 1)).map(\.id.remoteID) == ["2"])
        #expect(try await store.articles(ArticleQuery(limit: 0)).isEmpty)
    }

    @Test func `Konto Artikel Einstellungen und Pendingänderung überleben erneutes Öffnen`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Reader.store")
        let account = ReaderAccount(id: accountID, serverURL: try #require(URL(string: "https://example.com/api/greader.php")), username: "test")
        let original = article()
        let store = try ReaderStore(url: url)
        try await store.saveAccount(account)
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .starred, value: true)
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let reopened = try ReaderStore(url: url)
        #expect(try await reopened.accounts() == [account])
        #expect(try await reopened.articles(ArticleQuery()).first?.starred == true)
        #expect(try await reopened.preferences().first?.mode == .digest)
        #expect(try await reopened.pendingChanges(accountID: accountID).count == 1)
    }

    @Test func `Kontofremde Refreshdaten werden vor jeder Mutation abgelehnt`() async throws {
        let store = try ReaderStore(inMemory: true)
        var foreign = article()
        foreign.id.accountID = UUID()
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.applyRefresh(refresh(articles: [foreign]))
        }
        #expect(try await store.feeds().isEmpty)
        #expect(try await store.articles(ArticleQuery()).isEmpty)
    }

    @Test func `Volltextcache bleibt bei unverändertem Feed erhalten und wird bei Inhaltsänderung ungültig`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article(text: "Kurzer Feedtext")
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.updateContent(original.id, html: "<p>Langer extrahierter Volltext</p>", text: "Langer extrahierter Volltext")
        try await store.applyRefresh(refresh(articles: [original]))
        #expect(try await store.articles(ArticleQuery()).first?.text == "Langer extrahierter Volltext")
        #expect(try await store.articles(ArticleQuery(search: "extrahierter")).count == 1)
        try await store.applyRefresh(refresh(articles: [article(text: "Inzwischen geänderter Feedtext")]))
        #expect(try await store.articles(ArticleQuery()).first?.text == "Inzwischen geänderter Feedtext")
    }

    @Test func `Änderungsstream liefert Startrevision und bestätigte Schreibvorgänge`() async throws {
        let store = try ReaderStore(inMemory: true)
        let changes = await store.changes()
        var iterator = changes.makeAsyncIterator()
        #expect(await iterator.next() == 0)
        try await store.applyRefresh(refresh(articles: [article()]))
        #expect(await iterator.next() == 1)
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.setStatus([ArticleKey(accountID: accountID, remoteID: "fehlend")], field: .read, value: true)
        }
        try await store.setStatus([article().id], field: .read, value: true)
        #expect(await iterator.next() == 2)
    }

    @Test func `Mehrere Beobachter erhalten dieselbe bestätigte Änderung`() async throws {
        let store = try ReaderStore(inMemory: true)
        let firstStream = await store.changes()
        let secondStream = await store.changes()
        var first = firstStream.makeAsyncIterator()
        var second = secondStream.makeAsyncIterator()
        #expect(await first.next() == 0)
        #expect(await second.next() == 0)
        try await store.applyRefresh(refresh(articles: [article()]))
        #expect(await first.next() == 1)
        #expect(await second.next() == 1)
    }

    @Test func `Änderungsstream hält den Store nicht im Besitzkreis`() async throws {
        var store: ReaderStore? = try ReaderStore(inMemory: true)
        weak let weakStore = store
        let changes = await store?.changes()
        store = nil
        #expect(weakStore == nil)
        var iterator = changes?.makeAsyncIterator()
        #expect(await iterator?.next() == 0)
        #expect(await iterator?.next() == nil)
    }

    @Test func `Exakte Artikelabfrage findet Quellen außerhalb der ersten Seite`() async throws {
        let store = try ReaderStore(inMemory: true)
        let originals = (0..<210).map { article(String($0), arrived: Date(timeIntervalSince1970: Double($0))) }
        try await store.applyRefresh(refresh(articles: originals))
        let key = ArticleKey(accountID: accountID, remoteID: "0")
        #expect(try await store.articles(ArticleQuery()).contains { $0.id == key } == false)
        #expect(try await store.article(key)?.id == key)
        #expect(try await store.article(ArticleKey(accountID: UUID(), remoteID: "0")) == nil)
    }

    @Test func `Ordnerabfragen bleiben auf Mitgliedschaften und Konto begrenzt`() async throws {
        let store = try ReaderStore(inMemory: true)
        var firstFeed = feed
        firstFeed.folderIDs = ["folder/1"]
        let secondFeed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/2"), title: "Anderer Feed",
                                      url: fixtureURL, folderIDs: ["folder/2"])
        var secondArticle = article("2")
        secondArticle.feedID = secondFeed.id.remoteID
        let folders = ["folder/1", "folder/2", "empty"].map { FolderSnapshot(accountID: accountID, remoteID: $0, title: $0) }
        try await store.applyRefresh(refresh(articles: [article("1"), secondArticle], feeds: [firstFeed, secondFeed], folders: folders))
        let otherAccount = UUID()
        let foreignFeed = FeedSnapshot(id: FeedKey(accountID: otherAccount, remoteID: "feed/1"), title: "Anderes Konto",
                                      url: fixtureURL, folderIDs: ["folder/1"])
        let foreignArticle = ArticleSnapshot(id: ArticleKey(accountID: otherAccount, remoteID: "3"),
                                             feedID: "feed/1", title: "Anderer Artikel")
        try await store.applyRefresh(RefreshSnapshot(accountID: otherAccount, feeds: [foreignFeed],
            folders: [FolderSnapshot(accountID: otherAccount, remoteID: "folder/1", title: "folder/1")],
            articles: [foreignArticle], unreadIDs: ["3"], starredIDs: []))
        #expect(try await store.articles(ArticleQuery(accountID: accountID, folderID: "folder/1")).map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery(accountID: accountID, folderID: "folder/2")).map(\.id.remoteID) == ["2"])
        #expect(try await store.articles(ArticleQuery(accountID: accountID, folderID: "empty")).isEmpty)
        #expect(try await store.articles(ArticleQuery(accountID: otherAccount, folderID: "folder/1")).map(\.id.remoteID) == ["3"])
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.articles(ArticleQuery(folderID: "folder/1"))
        }
    }

    @Test func `Verspätete Extraktion überschreibt keine neuere Quellenfassung`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article(title: "Alter Titel", text: "Alter Inhalt")
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.applyRefresh(refresh(articles: [article(title: "Neuer Titel", text: "Neuer Inhalt")]))
        #expect(try await store.updateContent(original, html: "<p>Veraltet</p>", text: "Veraltet") == false)
        let current = try #require(try await store.article(original.id))
        #expect(current.title == "Neuer Titel")
        #expect(current.text == "Neuer Inhalt")
        #expect(try await store.updateContent(current, html: "<p>Aktueller Volltext</p>", text: "Aktueller Volltext"))
    }

    @Test func `Statusänderung macht eine inhaltlich passende Extraktion nicht ungültig`() async throws {
        let store = try ReaderStore(inMemory: true)
        let repository: any ReaderRepository = store
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .read, value: true)
        #expect(try await repository.updateContent(original, html: "<p>Volltext</p>", text: "Volltext"))
        #expect(try await store.article(original.id)?.read == true)
        #expect(try await store.pendingChanges(accountID: accountID).count == 1)
    }

    @Test func `Tagesübersicht wird bei neuen Tagesquellen nicht mit altem Stand überschrieben`() async throws {
        let store = try ReaderStore(inMemory: true)
        let repository: any ReaderRepository = store
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(timeIntervalSince1970: 0), timeZoneID: "UTC",
                                    sections: [], sources: [original.id])
        #expect(try await repository.saveDigest(digest, expectedSources: [original]))
        try await store.applyRefresh(refresh(articles: [article("2")], unread: ["1", "2"]))
        var stale = digest
        stale.revision = UUID()
        #expect(try await store.saveDigest(stale, expectedSources: [original]) == false)
        #expect(try await store.digests().first?.revision == digest.revision)
    }

    @Test func `Tagesübersicht akzeptiert Statusänderung und verwirft geänderten Inhalt`() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(timeIntervalSince1970: 0), timeZoneID: "UTC",
                                    sections: [], sources: [original.id])
        try await store.setStatus([original.id], field: .read, value: true)
        #expect(try await store.saveDigest(digest, expectedSources: [original]))
        try await store.applyRefresh(refresh(articles: [article(text: "Geändert")]))
        #expect(try await store.saveDigest(digest, expectedSources: [original]) == false)
    }

    @Test func `Importierte Homepage ergänzt fehlende Servermetadaten und bewahrt Servervorrang`() async throws {
        let store = try ReaderStore(inMemory: true)
        let imported = try #require(URL(string: "https://imported.example.org/"))
        let remote = try #require(URL(string: "https://server.example.org/"))
        try await store.applyRefresh(refresh(articles: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, importedHomePageURL: imported, importedFolderPath: ["A", "Nachrichten"]))
        #expect(try await store.feeds().first?.homePageURL == imported)
        #expect(try await store.preferences().first?.importedFolderPath == ["A", "Nachrichten"])
        var serverFeed = feed
        serverFeed.homePageURL = remote
        try await store.applyRefresh(refresh(articles: [], feeds: [serverFeed]))
        #expect(try await store.feeds().first?.homePageURL == remote)
        try await store.applyRefresh(refresh(articles: []))
        #expect(try await store.feeds().first?.homePageURL == imported)
    }

    @Test func `Neue Originaladresse verwirft Volltext der bisherigen Adresse`() async throws {
        let store = try ReaderStore(inMemory: true)
        var original = article(text: "Kurzer Feedtext")
        original.url = fixtureURL
        try await store.applyRefresh(refresh(articles: [original]))
        #expect(try await store.updateContent(original, html: "<p>Alter Volltext</p>", text: "Alter Volltext"))
        var updated = original
        updated.url = URL(string: "https://example.org/neuer-artikel")
        try await store.applyRefresh(refresh(articles: [updated]))
        #expect(try await store.article(original.id)?.text == "Kurzer Feedtext")
        #expect(try await store.article(original.id)?.url == updated.url)
    }

    @Test func `Importmerge erhält zwischenzeitlich widerrufene Cloudfreigabe und aktuelle Darstellungswahl`() async throws {
        let store = try ReaderStore(inMemory: true)
        let repository: any ReaderRepository = store
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .normal, timeZoneID: "Europe/Vienna", cloudAllowed: true))
        // Import preparation may have happened before the user changes these independent fields.
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, timeZoneID: "UTC", cloudAllowed: false))
        try await repository.mergeImportMetadata(feed: feed.id, homePageURL: fixtureURL,
                                                 folderPath: ["Import", "Nachrichten"], feedURL: fixtureURL)
        let current = try #require(try await store.preferences().first)
        #expect(current.cloudAllowed == false)
        #expect(current.mode == .digest)
        #expect(current.timeZoneID == "UTC")
        #expect(current.importedHomePageURL == fixtureURL)
        #expect(current.importedFeedURL == fixtureURL)
        #expect(current.importedFolderPath == ["Import", "Nachrichten"])
    }

    @Test func `Importmerge behält bekannte URLs und übernimmt nur nichtleere neue Ordnerpfade`() async throws {
        let store = try ReaderStore(inMemory: true)
        let otherURL = try #require(URL(string: "https://other.example.org/feed"))
        try await store.mergeImportMetadata(feed: feed.id, homePageURL: fixtureURL,
                                           folderPath: ["A", "Nachrichten"], feedURL: fixtureURL)
        try await store.mergeImportMetadata(feed: feed.id, homePageURL: otherURL, folderPath: [], feedURL: otherURL)
        var current = try #require(try await store.preferences().first)
        #expect(current.importedHomePageURL == fixtureURL)
        #expect(current.importedFeedURL == fixtureURL)
        #expect(current.importedFolderPath == ["A", "Nachrichten"])
        try await store.mergeImportMetadata(feed: feed.id, homePageURL: nil,
                                           folderPath: ["B", "Neu"], feedURL: otherURL)
        current = try #require(try await store.preferences().first)
        #expect(current.importedFolderPath == ["B", "Neu"])
        #expect(current.importedHomePageURL == fixtureURL)
        #expect(current.importedFeedURL == fixtureURL)
    }
}
