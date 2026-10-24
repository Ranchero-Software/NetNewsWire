import Foundation

public struct ArticleKey: Hashable, Codable, Sendable, Identifiable {
    public var accountID: UUID
    public var remoteID: String
    public var id: String { accountID.uuidString + "/" + remoteID }
    public init(accountID: UUID, remoteID: String) { self.accountID = accountID; self.remoteID = remoteID }
}

public struct FeedKey: Hashable, Codable, Sendable, Identifiable {
    public var accountID: UUID
    public var remoteID: String
    public var id: String { accountID.uuidString + "/" + remoteID }
    public init(accountID: UUID, remoteID: String) { self.accountID = accountID; self.remoteID = remoteID }
}

public struct ReaderAccount: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var serverURL: URL
    public var username: String
    public var name: String
    public init(id: UUID = UUID(), serverURL: URL, username: String, name: String = "FreshRSS") {
        self.id = id; self.serverURL = serverURL; self.username = username; self.name = name
    }
}

public struct FeedSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: FeedKey
    public var title: String
    public var url: URL
    public var homePageURL: URL?
    public var folderIDs: [String]
    public init(id: FeedKey, title: String, url: URL, homePageURL: URL? = nil, folderIDs: [String] = []) {
        self.id = id; self.title = title; self.url = url; self.homePageURL = homePageURL; self.folderIDs = folderIDs
    }
}

public struct FolderSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var accountID: UUID
    public var remoteID: String
    public var title: String
    public var id: String { accountID.uuidString + "/" + remoteID }
    public init(accountID: UUID, remoteID: String, title: String) {
        self.accountID = accountID; self.remoteID = remoteID; self.title = title
    }
}

public struct ArticleSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: ArticleKey
    public var feedID: String
    public var title: String
    public var html: String
    public var text: String
    public var url: URL?
    public var datePublished: Date?
    public var dateArrived: Date
    public var read: Bool
    public var starred: Bool
    public init(id: ArticleKey, feedID: String, title: String, html: String = "", text: String = "", url: URL? = nil,
                datePublished: Date? = nil, dateArrived: Date = Date(), read: Bool = false, starred: Bool = false) {
        self.id = id; self.feedID = feedID; self.title = title; self.html = html; self.text = text; self.url = url
        self.datePublished = datePublished; self.dateArrived = dateArrived; self.read = read; self.starred = starred
    }
}

public enum FeedMode: String, Codable, CaseIterable, Sendable { case normal, digest }
public struct FeedPreferences: Identifiable, Hashable, Codable, Sendable {
    public var id: FeedKey
    public var mode: FeedMode
    public var timeZoneID: String
    public var cloudAllowed: Bool
    public var importedHomePageURL: URL?
    public var importedFeedURL: URL?
    public var importedFolderPath: [String]
    public init(id: FeedKey, mode: FeedMode = .normal, timeZoneID: String = TimeZone.current.identifier, cloudAllowed: Bool = false,
                importedHomePageURL: URL? = nil, importedFolderPath: [String] = [], importedFeedURL: URL? = nil) {
        self.id = id; self.mode = mode; self.timeZoneID = timeZoneID; self.cloudAllowed = cloudAllowed
        self.importedHomePageURL = importedHomePageURL; self.importedFolderPath = importedFolderPath
        self.importedFeedURL = importedFeedURL
    }
}

public enum StatusField: String, Codable, Sendable { case read, starred }
public struct PendingChange: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var article: ArticleKey
    public var field: StatusField
    public var value: Bool
    public init(id: UUID = UUID(), article: ArticleKey, field: StatusField, value: Bool) {
        self.id = id; self.article = article; self.field = field; self.value = value
    }
}

public struct ArticleQuery: Hashable, Sendable {
    public var accountID: UUID?
    public var folderID: String?
    public var feed: FeedKey?
    public var unreadOnly: Bool
    public var starredOnly: Bool
    public var search: String
    public var offset: Int
    public var limit: Int
    public init(accountID: UUID? = nil, folderID: String? = nil, feed: FeedKey? = nil, unreadOnly: Bool = false, starredOnly: Bool = false,
                search: String = "", offset: Int = 0, limit: Int = 200) {
        self.accountID = accountID; self.folderID = folderID; self.feed = feed; self.unreadOnly = unreadOnly; self.starredOnly = starredOnly
        self.search = search; self.offset = offset; self.limit = limit
    }
}

public struct RefreshSnapshot: Sendable {
    public var accountID: UUID
    public var feeds: [FeedSnapshot]
    public var folders: [FolderSnapshot]
    public var articles: [ArticleSnapshot]
    public var unreadIDs: Set<String>
    public var starredIDs: Set<String>
    public init(accountID: UUID, feeds: [FeedSnapshot], folders: [FolderSnapshot], articles: [ArticleSnapshot], unreadIDs: Set<String>, starredIDs: Set<String>) {
        self.accountID = accountID; self.feeds = feeds; self.folders = folders; self.articles = articles
        self.unreadIDs = unreadIDs; self.starredIDs = starredIDs
    }
}

public struct DigestSection: Hashable, Codable, Sendable {
    public var title: String
    public var text: String
    public var sources: [ArticleKey]
    public init(title: String, text: String, sources: [ArticleKey]) { self.title = title; self.text = text; self.sources = sources }
}

public struct DigestSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var revision: UUID
    public var feed: FeedKey
    public var day: Date
    public var timeZoneID: String
    public var sections: [DigestSection]
    public var sources: [ArticleKey]
    public var warning: String?
    public var generatedAt: Date
    public var sourceFingerprint: String
    public init(id: String, revision: UUID = UUID(), feed: FeedKey, day: Date, timeZoneID: String,
                sections: [DigestSection], sources: [ArticleKey], warning: String? = nil, generatedAt: Date = Date(), sourceFingerprint: String = "") {
        self.id = id; self.revision = revision; self.feed = feed; self.day = day; self.timeZoneID = timeZoneID
        self.sections = sections; self.sources = sources; self.warning = warning; self.generatedAt = generatedAt
        self.sourceFingerprint = sourceFingerprint
    }
}

public enum ReaderError: Error, LocalizedError, Equatable, Sendable {
    case invalidURL, invalidResponse, unauthorized, unavailable(String), server(Int), staleResult
    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Ungültige Serveradresse."
        case .invalidResponse: "Die Antwort konnte nicht verarbeitet werden."
        case .unauthorized: "Anmeldung fehlgeschlagen. Bitte API-Passwort prüfen."
        case .unavailable(let reason): reason
        case .server(let status): "Serverfehler (HTTP \(status))."
        case .staleResult: "Der Auftrag wurde durch einen neueren ersetzt."
        }
    }
}
