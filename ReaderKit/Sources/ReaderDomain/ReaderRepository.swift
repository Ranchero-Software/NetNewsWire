import Foundation

public protocol ReaderRepository: Sendable {
    func accounts() async throws -> [ReaderAccount]
    func saveAccount(_ account: ReaderAccount) async throws
    func feeds() async throws -> [FeedSnapshot]
    func folders() async throws -> [FolderSnapshot]
    func articles(_ query: ArticleQuery) async throws -> [ArticleSnapshot]
    func article(_ key: ArticleKey) async throws -> ArticleSnapshot?
    func changes() async -> AsyncStream<UInt64>
    func applyRefresh(_ snapshot: RefreshSnapshot) async throws
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) async throws
    func pendingChanges(accountID: UUID) async throws -> [PendingChange]
    func acknowledge(_ changes: [PendingChange]) async throws
    func preferences() async throws -> [FeedPreferences]
    func savePreferences(_ preferences: FeedPreferences) async throws
    func mergeImportMetadata(feed: FeedKey, homePageURL: URL?, folderPath: [String], feedURL: URL) async throws
    func digests() async throws -> [DigestSnapshot]
    func saveDigest(_ digest: DigestSnapshot) async throws
    func saveDigest(_ digest: DigestSnapshot, expectedSources: [ArticleSnapshot]) async throws -> Bool
    func updateContent(_ key: ArticleKey, html: String, text: String) async throws
    func updateContent(_ source: ArticleSnapshot, html: String, text: String) async throws -> Bool
}

public extension ReaderRepository {
    func mergeImportMetadata(feed: FeedKey, homePageURL: URL?, folderPath: [String], feedURL: URL) async throws {
        throw ReaderError.unavailable("Dieser Speicher unterstützt keinen atomaren Metadatenimport.")
    }
    func saveDigest(_ digest: DigestSnapshot, expectedSources: [ArticleSnapshot]) async throws -> Bool {
        throw ReaderError.unavailable("Dieser Speicher unterstützt keine atomare Quellenprüfung.")
    }
    func updateContent(_ source: ArticleSnapshot, html: String, text: String) async throws -> Bool {
        throw ReaderError.unavailable("Dieser Speicher unterstützt keine atomare Quellenprüfung.")
    }
    func changes() async -> AsyncStream<UInt64> { AsyncStream { $0.finish() } }
    func article(_ key: ArticleKey) async throws -> ArticleSnapshot? {
        var offset = 0
        while true {
            let page = try await articles(ArticleQuery(accountID: key.accountID, offset: offset, limit: 200))
            if let match = page.first(where: { $0.id == key }) { return match }
            if page.count < 200 { return nil }
            offset += page.count
        }
    }
}

public protocol CredentialStore: Sendable {
    func password(accountID: UUID) async throws -> String?
    func savePassword(_ password: String, accountID: UUID) async throws
    func removePassword(accountID: UUID) async throws
}

public protocol SummaryGenerator: Sendable {
    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection]
    func summarize(_ articles: [ArticleSnapshot], cloudPermission: @escaping @Sendable () async throws -> Bool) async throws -> [DigestSection]
}

public extension SummaryGenerator {
    func summarize(_ articles: [ArticleSnapshot], cloudPermission: @escaping @Sendable () async throws -> Bool) async throws -> [DigestSection] {
        // Implementations without a live authorization check may only use local inference.
        try await summarize(articles, cloudAllowed: false)
    }
}
