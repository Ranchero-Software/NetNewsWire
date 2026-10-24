import Foundation
import SwiftData
import ReaderDomain

@Model final class AccountRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

@Model final class FeedRecord {
    @Attribute(.unique) var key: String
    var accountID: UUID
    var remoteID: String
    var payload: Data
    init(_ snapshot: FeedSnapshot, payload: Data) {
        key = snapshot.id.id; accountID = snapshot.id.accountID; remoteID = snapshot.id.remoteID; self.payload = payload
    }
}

@Model final class FolderRecord {
    @Attribute(.unique) var key: String
    var accountID: UUID
    var payload: Data
    init(_ snapshot: FolderSnapshot, payload: Data) {
        key = snapshot.id; accountID = snapshot.accountID; self.payload = payload
    }
}

@Model final class ArticleRecord {
    #Index<ArticleRecord>([\.accountID, \.dateArrived], [\.accountID, \.feedID, \.dateArrived])
    @Attribute(.unique) var key: String
    var accountID: UUID
    var remoteID: String
    var feedID: String
    var title: String
    var html: String
    var text: String
    var sourceHTML: String
    var sourceText: String
    var searchText: String
    var urlString: String?
    var datePublished: Date?
    var dateArrived: Date
    var read: Bool
    var starred: Bool

    init(_ snapshot: ArticleSnapshot) {
        key = snapshot.id.id; accountID = snapshot.id.accountID; remoteID = snapshot.id.remoteID
        feedID = snapshot.feedID; title = snapshot.title; html = snapshot.html; text = snapshot.text
        sourceHTML = snapshot.html; sourceText = snapshot.text
        searchText = Self.normalize(snapshot.title + "\n" + snapshot.text)
        urlString = snapshot.url?.absoluteString; datePublished = snapshot.datePublished
        dateArrived = snapshot.dateArrived; read = snapshot.read; starred = snapshot.starred
    }

    func replaceContent(_ snapshot: ArticleSnapshot) {
        feedID = snapshot.feedID; title = snapshot.title
        // A refresh with unchanged feed text must not discard a locally extracted full text.
        if sourceHTML != snapshot.html || sourceText != snapshot.text || urlString != snapshot.url?.absoluteString {
            html = snapshot.html; text = snapshot.text
        }
        sourceHTML = snapshot.html; sourceText = snapshot.text
        searchText = Self.normalize(snapshot.title + "\n" + text)
        urlString = snapshot.url?.absoluteString; datePublished = snapshot.datePublished
        // First arrival determines the digest day and survives content updates.
    }

    var snapshot: ArticleSnapshot {
        ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: remoteID), feedID: feedID,
                        title: title, html: html, text: text, url: urlString.flatMap(URL.init(string:)),
                        datePublished: datePublished, dateArrived: dateArrived, read: read, starred: starred)
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
    }
}

@Model final class PreferenceRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

@Model final class DigestRecord {
    @Attribute(.unique) var key: String
    var day: Date
    var payload: Data
    init(_ snapshot: DigestSnapshot, payload: Data) { key = snapshot.id; day = snapshot.day; self.payload = payload }
}

@Model final class PendingRecord {
    @Attribute(.unique) var key: String
    var revision: UUID
    var accountID: UUID
    var remoteID: String
    var field: String
    var value: Bool
    init(_ change: PendingChange) {
        key = Self.key(for: change.article, field: change.field); revision = change.id
        accountID = change.article.accountID; remoteID = change.article.remoteID
        field = change.field.rawValue; value = change.value
    }
    static func key(for article: ArticleKey, field: StatusField) -> String { article.id + "/" + field.rawValue }
    var snapshot: PendingChange? {
        guard let statusField = StatusField(rawValue: field) else { return nil }
        return PendingChange(id: revision, article: ArticleKey(accountID: accountID, remoteID: remoteID),
                             field: statusField, value: value)
    }
}

enum ReaderSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [AccountRecord.self, FeedRecord.self, FolderRecord.self, ArticleRecord.self,
         PreferenceRecord.self, DigestRecord.self, PendingRecord.self]
    }
}
