import Foundation
import Testing
import ReaderContent
import ReaderDomain

struct ContentTests {
    @Test func `OPML erhält Homepage und Ordner beim Roundtrip`() throws {
        let account = UUID()
        let feed = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "feed/1"), title: "Äpfel & Öl",
            url: try #require(URL(string: "https://example.org/rss")), homePageURL: URL(string: "https://example.org"), folderIDs: ["news"])
        let folder = FolderSnapshot(accountID: account, remoteID: "news", title: "Österreich")
        let parsed = try OPMLDocument.parse(OPMLDocument.export(feeds: [feed], folders: [folder]))
        #expect(parsed.count == 1)
        #expect(parsed.first?.title == feed.title)
        #expect(parsed.first?.homePageURL == feed.homePageURL)
        #expect(parsed.first?.folderPath == ["Österreich"])
    }
    @Test(arguments: ["<opml><body>", "<rss/>", "<opml><body><outline xmlUrl='file:///private'/></body></opml>"])
    func `Ungültiges OPML wird abgelehnt`(xml: String) {
        #expect(throws: (any Error).self) { try OPMLDocument.parse(Data(xml.utf8)) }
    }
    @Test func `Verschachtelte gleichnamige Ordner bleiben beim Export getrennt`() throws {
        let account = UUID()
        let first = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "a"), title: "A", url: try #require(URL(string: "https://a.example/rss")))
        let second = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "b"), title: "B", url: try #require(URL(string: "https://b.example/rss")))
        let prefs = [FeedPreferences(id: first.id, importedFolderPath: ["A", "News"]), FeedPreferences(id: second.id, importedFolderPath: ["B", "News"])]
        let subscriptions = try OPMLDocument.parse(OPMLDocument.export(feeds: [first, second], folders: [], preferences: prefs))
        #expect(subscriptions.map(\.folderPath) == [["A", "News"], ["B", "News"]])
    }
    @Test func `Volltext wird ohne Ausführung von Seitenskripten extrahiert`() async throws {
        let content = ArticleContentService()
        let html = "<html><head><title>Angebote</title></head><body><article><h1>Äpfel um 2,99 €</h1><p>" + String(repeating: "Frische Äpfel beim Händler. ", count: 80) + "<a href='/angebot'>Zum Angebot</a></p><script>throw new Error('page script must not execute')</script></article></body></html>"
        let result = try await content.extract(html: html, baseURL: #require(URL(string: "https://example.org/deal")))
        #expect(result.text.contains("Äpfel"))
        #expect(!result.text.contains("page script must not execute"))
        #expect(result.html.contains("https://example.org/angebot"))
    }
}
