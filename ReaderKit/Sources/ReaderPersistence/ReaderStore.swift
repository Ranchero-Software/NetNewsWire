import Foundation
import SwiftData
import ReaderDomain

/// One actor owns every ModelContext operation. Only immutable domain snapshots leave it.
public actor ReaderStore: ReaderRepository {
    private let container: ModelContainer
    private var storedContext: ModelContext?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var revision: UInt64 = 0
    private var observers: [UUID: AsyncStream<UInt64>.Continuation] = [:]

    /// A distinct URL per app configuration separates Debug, Release and test stores.
    public init(url: URL? = nil, inMemory: Bool = false) throws {
        let schema = Schema(versionedSchema: ReaderSchemaV1.self)
        let configuration: ModelConfiguration
        if let url, !inMemory {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("Reader", schema: schema,
                                               isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    deinit {
        for continuation in observers.values { continuation.finish() }
    }

    /// Buffered current revision plus committed writes; termination never retains the store.
    public func changes() async -> AsyncStream<UInt64> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<UInt64>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        observers[id] = continuation
        continuation.yield(revision)
        return stream
    }

    private func removeObserver(_ id: UUID) { observers[id] = nil }

    private var context: ModelContext {
        if let storedContext { return storedContext }
        // Created after entering the actor, never inherited from a SwiftUI scene.
        let newContext = ModelContext(container)
        newContext.autosaveEnabled = false
        storedContext = newContext
        return newContext
    }

    private func write(_ operation: () throws -> Void) throws {
        do {
            try context.transaction { try operation() }
            revision &+= 1
            for continuation in observers.values { continuation.yield(revision) }
        } catch {
            context.rollback()
            throw error
        }
    }

    public func accounts() throws -> [ReaderAccount] {
        try context.fetch(FetchDescriptor<AccountRecord>(sortBy: [SortDescriptor(\.key)]))
            .map { try decoder.decode(ReaderAccount.self, from: $0.payload) }
    }

    public func saveAccount(_ account: ReaderAccount) throws {
        let key = account.id.uuidString
        let payload = try encoder.encode(account)
        try write {
            let descriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.key == key })
            if let existing = try context.fetch(descriptor).first { existing.payload = payload } else { context.insert(AccountRecord(key: key, payload: payload)) }
        }
    }

    public func feeds() throws -> [FeedSnapshot] {
        let settings = Dictionary(uniqueKeysWithValues: try preferences().map { ($0.id, $0) })
        return try context.fetch(FetchDescriptor<FeedRecord>(sortBy: [SortDescriptor(\.key)]))
            .map { record in
                var feed = try decoder.decode(FeedSnapshot.self, from: record.payload)
                if feed.homePageURL == nil { feed.homePageURL = settings[feed.id]?.importedHomePageURL }
                return feed
            }
    }

    public func folders() throws -> [FolderSnapshot] {
        try context.fetch(FetchDescriptor<FolderRecord>(sortBy: [SortDescriptor(\.key)]))
            .map { try decoder.decode(FolderSnapshot.self, from: $0.payload) }
    }

    public func articles(_ query: ArticleQuery) throws -> [ArticleSnapshot] {
        if query.folderID != nil, query.accountID == nil { throw ReaderError.invalidResponse }
        guard query.limit > 0 else { return [] }
        let filterAccount = query.accountID != nil || query.feed != nil
        let accountID = query.accountID ?? query.feed?.accountID ?? UUID()
        let filterFeed = query.feed != nil
        let feedID = query.feed?.remoteID ?? ""
        let filterFolder = query.folderID != nil
        let allowedFeedIDs: [String]
        if let folderID = query.folderID, let folderAccountID = query.accountID {
            let records = try context.fetch(FetchDescriptor<FeedRecord>(predicate: #Predicate { $0.accountID == folderAccountID }))
            allowedFeedIDs = try records.compactMap { record in
                let feed = try decoder.decode(FeedSnapshot.self, from: record.payload)
                return feed.folderIDs.contains(folderID) ? feed.id.remoteID : nil
            }
        } else { allowedFeedIDs = [] }
        let unreadOnly = query.unreadOnly
        let starredOnly = query.starredOnly
        let search = ArticleRecord.normalize(query.search.trimmingCharacters(in: .whitespacesAndNewlines))
        var descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { article in
            (!filterAccount || article.accountID == accountID)
                && (!filterFeed || article.feedID == feedID)
                && (!filterFolder || allowedFeedIDs.contains(article.feedID))
                && (!unreadOnly || !article.read)
                && (!starredOnly || article.starred)
                && (search.isEmpty || article.searchText.contains(search))
        }, sortBy: [SortDescriptor(\.dateArrived, order: .reverse), SortDescriptor(\.key)])
        descriptor.fetchOffset = max(0, query.offset)
        descriptor.fetchLimit = min(query.limit, 1_000)
        return try context.fetch(descriptor).map(\.snapshot)
    }

    public func article(_ key: ArticleKey) async throws -> ArticleSnapshot? {
        let recordKey = key.id
        var descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.key == recordKey })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.snapshot
    }

    /// Only call after all required FreshRSS pages/status responses succeeded.
    public func applyRefresh(_ snapshot: RefreshSnapshot) throws {
        let accountID = snapshot.accountID
        guard snapshot.feeds.allSatisfy({ $0.id.accountID == accountID }),
              snapshot.folders.allSatisfy({ $0.accountID == accountID }),
              snapshot.articles.allSatisfy({ $0.id.accountID == accountID }) else { throw ReaderError.invalidResponse }
        try write {
            let pendingRecords = try context.fetch(FetchDescriptor<PendingRecord>(predicate: #Predicate { $0.accountID == accountID }))
            let pending = Dictionary(uniqueKeysWithValues: pendingRecords.map { ($0.key, $0) })
            let oldFeeds = try context.fetch(FetchDescriptor<FeedRecord>(predicate: #Predicate { $0.accountID == accountID }))
            let feedMap = Dictionary(uniqueKeysWithValues: oldFeeds.map { ($0.key, $0) })
            let incomingFeedKeys = Set(snapshot.feeds.map(\.id.id))
            let subscribedIDs = Set(snapshot.feeds.map(\.id.remoteID))
            for record in oldFeeds where !incomingFeedKeys.contains(record.key) { context.delete(record) }
            // A duplicate remote identity selects the last whole version in response order.
            var canonicalFeeds: [String: FeedSnapshot] = [:]
            for feed in snapshot.feeds { canonicalFeeds[feed.id.id] = feed }
            for feed in canonicalFeeds.values {
                let payload = try encoder.encode(feed)
                if let record = feedMap[feed.id.id] { record.payload = payload } else { context.insert(FeedRecord(feed, payload: payload)) }
            }
            let oldFolders = try context.fetch(FetchDescriptor<FolderRecord>(predicate: #Predicate { $0.accountID == accountID }))
            let folderMap = Dictionary(uniqueKeysWithValues: oldFolders.map { ($0.key, $0) })
            var canonicalFolders: [String: FolderSnapshot] = [:]
            for folder in snapshot.folders { canonicalFolders[folder.id] = folder }
            for record in oldFolders where canonicalFolders[record.key] == nil { context.delete(record) }
            for folder in canonicalFolders.values {
                let payload = try encoder.encode(folder)
                if let record = folderMap[folder.id] { record.payload = payload } else { context.insert(FolderRecord(folder, payload: payload)) }
            }
            let oldArticles = try context.fetch(FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.accountID == accountID }))
            var articleMap = Dictionary(uniqueKeysWithValues: oldArticles.map { ($0.key, $0) })
            var canonicalArticles: [String: ArticleSnapshot] = [:]
            for article in snapshot.articles { canonicalArticles[article.id.id] = article }
            for article in canonicalArticles.values {
                if let existing = articleMap[article.id.id] { existing.replaceContent(article) } else {
                    let record = ArticleRecord(article)
                    context.insert(record)
                    articleMap[article.id.id] = record
                }
            }
            let referencedKeys = try digestSourceKeys()
            for article in articleMap.values {
                let articleKey = ArticleKey(accountID: accountID, remoteID: article.remoteID)
                let readKey = PendingRecord.key(for: articleKey, field: .read)
                let starKey = PendingRecord.key(for: articleKey, field: .starred)
                if let change = pending[readKey] { article.read = change.value } else { article.read = !snapshot.unreadIDs.contains(article.remoteID) }
                if let change = pending[starKey] { article.starred = change.value } else if subscribedIDs.contains(article.feedID) || !article.starred {
                    article.starred = snapshot.starredIDs.contains(article.remoteID)
                }
                if !subscribedIDs.contains(article.feedID), !article.starred,
                   pending[readKey] == nil, pending[starKey] == nil,
                   !referencedKeys.contains(article.key) { context.delete(article) }
            }
        }
    }

    public func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) throws {
        try write {
            for key in Set(keys).sorted(by: { $0.id < $1.id }) {
                let recordKey = key.id
                let descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.key == recordKey })
                guard let record = try context.fetch(descriptor).first else { throw ReaderError.invalidResponse }
                switch field {
                case .read: record.read = value
                case .starred: record.starred = value
                }
                let queueKey = PendingRecord.key(for: key, field: field)
                let queueDescriptor = FetchDescriptor<PendingRecord>(predicate: #Predicate { $0.key == queueKey })
                let change = PendingChange(article: key, field: field, value: value)
                if let pending = try context.fetch(queueDescriptor).first {
                    pending.revision = change.id
                    pending.value = value
                } else { context.insert(PendingRecord(change)) }
            }
        }
    }

    public func pendingChanges(accountID: UUID) throws -> [PendingChange] {
        try context.fetch(FetchDescriptor<PendingRecord>(predicate: #Predicate { $0.accountID == accountID },
                                                        sortBy: [SortDescriptor(\.key)]))
            .map { record in
                guard let snapshot = record.snapshot else { throw ReaderError.invalidResponse }
                return snapshot
            }
    }

    public func acknowledge(_ changes: [PendingChange]) throws {
        try write {
            for change in changes {
                let key = PendingRecord.key(for: change.article, field: change.field)
                let descriptor = FetchDescriptor<PendingRecord>(predicate: #Predicate { $0.key == key })
                if let record = try context.fetch(descriptor).first, record.revision == change.id {
                    context.delete(record)
                }
            }
        }
    }

    public func preferences() throws -> [FeedPreferences] {
        try context.fetch(FetchDescriptor<PreferenceRecord>(sortBy: [SortDescriptor(\.key)]))
            .map { try decoder.decode(FeedPreferences.self, from: $0.payload) }
    }

    public func savePreferences(_ preferences: FeedPreferences) throws {
        let key = preferences.id.id
        let payload = try encoder.encode(preferences)
        try write {
            let descriptor = FetchDescriptor<PreferenceRecord>(predicate: #Predicate { $0.key == key })
            if let existing = try context.fetch(descriptor).first { existing.payload = payload } else { context.insert(PreferenceRecord(key: key, payload: payload)) }
        }
    }

    /// Merge import-only fields into the latest preferences without overwriting a user's consent.
    public func mergeImportMetadata(feed: FeedKey, homePageURL: URL?, folderPath: [String], feedURL: URL) async throws {
        let key = feed.id
        try write {
            let descriptor = FetchDescriptor<PreferenceRecord>(predicate: #Predicate { $0.key == key })
            let existing = try context.fetch(descriptor).first
            var latest = try existing.map { try decoder.decode(FeedPreferences.self, from: $0.payload) }
                ?? FeedPreferences(id: feed)
            if latest.importedHomePageURL == nil { latest.importedHomePageURL = homePageURL }
            if latest.importedFeedURL == nil { latest.importedFeedURL = feedURL }
            if !folderPath.isEmpty { latest.importedFolderPath = folderPath }
            let payload = try encoder.encode(latest)
            if let existing { existing.payload = payload } else { context.insert(PreferenceRecord(key: key, payload: payload)) }
        }
    }

    public func digests() throws -> [DigestSnapshot] {
        try context.fetch(FetchDescriptor<DigestRecord>(sortBy: [SortDescriptor(\.day, order: .reverse), SortDescriptor(\.key)]))
            .map { try decoder.decode(DigestSnapshot.self, from: $0.payload) }
    }

    public func saveDigest(_ digest: DigestSnapshot) throws {
        guard digest.sources.allSatisfy({ $0.accountID == digest.feed.accountID }) else { throw ReaderError.invalidResponse }
        let key = digest.id
        let payload = try encoder.encode(digest)
        try write {
            let descriptor = FetchDescriptor<DigestRecord>(predicate: #Predicate { $0.key == key })
            if let existing = try context.fetch(descriptor).first {
                existing.day = digest.day; existing.payload = payload
            } else { context.insert(DigestRecord(digest, payload: payload)) }
        }
    }

    /// Commit only while both the source versions and the complete day's membership still match.
    public func saveDigest(_ digest: DigestSnapshot, expectedSources: [ArticleSnapshot]) async throws -> Bool {
        guard let timeZone = TimeZone(identifier: digest.timeZoneID) else { throw ReaderError.invalidResponse }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: digest.day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw ReaderError.invalidResponse }
        let accountID = digest.feed.accountID
        let feedID = digest.feed.remoteID
        let descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate {
            $0.accountID == accountID && $0.feedID == feedID && $0.dateArrived >= start && $0.dateArrived < end
        })
        let current = try context.fetch(descriptor)
        let expectedKeys = Set(expectedSources.map(\.id.id))
        guard expectedSources.count == expectedKeys.count,
              expectedKeys == Set(digest.sources.map(\.id)),
              expectedKeys == Set(current.map(\.key)) else { return false }
        let expected = Dictionary(uniqueKeysWithValues: expectedSources.map { ($0.id.id, $0) })
        for record in current {
            guard let source = expected[record.key], Self.matches(record, source: source),
                  record.dateArrived == source.dateArrived else { return false }
        }
        // There is no await between validation and save; another repository call cannot interleave.
        try saveDigest(digest)
        return true
    }

    public func updateContent(_ key: ArticleKey, html: String, text: String) throws {
        let recordKey = key.id
        try write {
            let descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.key == recordKey })
            guard let record = try context.fetch(descriptor).first else { throw ReaderError.invalidResponse }
            record.html = html; record.text = text
            record.searchText = ArticleRecord.normalize(record.title + "\n" + text)
        }
    }

    /// A delayed extraction may cache text only for the exact source version it was started for.
    public func updateContent(_ source: ArticleSnapshot, html: String, text: String) async throws -> Bool {
        let key = source.id.id
        let descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.key == key })
        guard let record = try context.fetch(descriptor).first, Self.matches(record, source: source) else { return false }
        try write {
            record.html = html; record.text = text
            record.searchText = ArticleRecord.normalize(record.title + "\n" + text)
        }
        return true
    }

    private static func matches(_ record: ArticleRecord, source: ArticleSnapshot) -> Bool {
        record.key == source.id.id && record.feedID == source.feedID && record.title == source.title
            && record.html == source.html && record.text == source.text
            && record.urlString.flatMap(URL.init(string:)) == source.url
    }

    private func digestSourceKeys() throws -> Set<String> {
        let digests = try context.fetch(FetchDescriptor<DigestRecord>())
        return try Set(digests.flatMap { record in
            try decoder.decode(DigestSnapshot.self, from: record.payload).sources.map(\.id)
        })
    }
}
