import Foundation
import Observation
import ReaderDomain
import ReaderContent

@MainActor @Observable
public final class ReaderSession {
    public let services: ReaderServices
    public var sidebarSelection: String?
    public var search = ""
    public var selection: TimelineSelection? {
        didSet {
            if case .digest(let id) = selection { displayedDigest = digests.first { $0.id == id } } else { displayedDigest = nil }
        }
    }
    public var errorMessage: String?
    public var showingAccount = false
    public private(set) var accounts: [ReaderAccount] = []
    public private(set) var feeds: [FeedSnapshot] = []
    public private(set) var folders: [FolderSnapshot] = []
    public private(set) var articles: [ArticleSnapshot] = []
    public private(set) var digests: [DigestSnapshot] = []
    public private(set) var feedPreferences: [FeedPreferences] = []
    public private(set) var rows: [TimelineRow] = []
    public private(set) var loading = false
    public private(set) var syncing = false
    public private(set) var generating = false
    public private(set) var canLoadMore = false
    public private(set) var sourceArticles: [ArticleSnapshot] = []
    public private(set) var loadingSources = false
    public private(set) var detailArticle: ArticleSnapshot?
    public private(set) var displayedDigest: DigestSnapshot?
    public private(set) var digestUnread: [String: Bool] = [:]
    private var generation = 0
    private var sourceGeneration = 0
    private var limit = 200

    public init(services: ReaderServices) { self.services = services }

    public var queryIdentity: String { (sidebarSelection ?? "unread") + "|" + search }
    public var selectedFeed: FeedSnapshot? { feeds.first { $0.id.id == sidebarSelection } }
    public var selectedFolder: FolderSnapshot? { folders.first { $0.id == sidebarSelection } }
    public var selectedArticle: ArticleSnapshot? {
        guard case .article(let key) = selection else { return nil }
        return articles.first { $0.id == key } ?? (detailArticle?.id == key ? detailArticle : nil) ?? sourceArticles.first { $0.id == key }
    }
    public var selectedDigest: DigestSnapshot? {
        guard case .digest(let id) = selection else { return nil }
        return displayedDigest?.id == id ? displayedDigest : nil
    }
    public var title: String {
        if let selectedFeed { return selectedFeed.title }
        if let selectedFolder { return selectedFolder.title }
        return sidebarSelection == "starred" ? "Markiert" : sidebarSelection == "unread" ? "Ungelesen" : "Alle Artikel"
    }

    public func reload(resetLimit: Bool = false) async {
        generation &+= 1
        let current = generation
        let queryID = queryIdentity
        if resetLimit { limit = 200 }
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let repository = services.repository
            let nextAccounts = try await repository.accounts()
            let nextFeeds = try await repository.feeds()
            let nextFolders = try await repository.folders()
            let nextPreferences = try await repository.preferences()
            let nextDigests = try await repository.digests()
            let selected = nextFeeds.first { $0.id.id == sidebarSelection }
            let folder = nextFolders.first { $0.id == sidebarSelection }
            var query = ArticleQuery(accountID: folder?.accountID, feed: selected?.id, unreadOnly: sidebarSelection == "unread",
                                     starredOnly: sidebarSelection == "starred", search: search, limit: 200)
            query.folderID = folder?.remoteID
            var nextArticles: [ArticleSnapshot] = []
            var page: [ArticleSnapshot] = []
            var fetchedCount = 0
            var requestedCount = 200
            var seen: Set<ArticleKey> = []
            let bundledFeeds = Set(nextPreferences.filter { $0.mode == .digest }.map(\.id))
            let coveredKeys = Set(nextDigests.filter { bundledFeeds.contains($0.feed) }.flatMap(\.sources))
            let includeCovered = !search.isEmpty || sidebarSelection == "starred" || selected != nil
            repeat {
                var nextQuery = query
                nextQuery.offset = fetchedCount
                requestedCount = min(200, max(1, limit - nextArticles.count))
                nextQuery.limit = requestedCount
                page = try await repository.articles(nextQuery)
                guard !Task.isCancelled, current == generation, queryID == queryIdentity else { return }
                fetchedCount += page.count
                nextArticles.append(contentsOf: page.filter {
                    (includeCovered || !coveredKeys.contains($0.id)) && seen.insert($0.id).inserted
                })
            } while page.count == requestedCount && nextArticles.count < limit
            var nextDigestUnread: [String: Bool] = [:]
            let loaded = Dictionary(uniqueKeysWithValues: nextArticles.map { ($0.id, $0) })
            for digest in nextDigests {
                for key in digest.sources {
                    let article = if let cached = loaded[key] { cached } else { try await repository.article(key) }
                    if article?.read == false { nextDigestUnread[digest.id] = true; break }
                }
            }
            guard !Task.isCancelled, current == generation, queryID == queryIdentity else { return }
            accounts = nextAccounts
            feeds = nextFeeds
            folders = nextFolders
            feedPreferences = nextPreferences
            digests = nextDigests
            articles = nextArticles
            digestUnread = nextDigestUnread
            canLoadMore = page.count == requestedCount
            rebuildRows()
            await loadSelectedArticle()
            if let displayedDigest { await loadSources(displayedDigest) }
        } catch is CancellationError {
        } catch {
            if current == generation { errorMessage = error.localizedDescription }
        }
    }

    private func rebuildRows() {
        let bundled = Set(feedPreferences.filter { $0.mode == .digest }.map(\.id))
        let folderFeedKeys: Set<FeedKey>? = selectedFolder.map { folder in
            Set(feeds.filter { $0.id.accountID == folder.accountID && $0.folderIDs.contains(folder.remoteID) }.map(\.id))
        }
        let showOriginals = !search.isEmpty || sidebarSelection == "starred" || selectedFeed != nil
        let covered = Set(digests.filter { bundled.contains($0.feed) }.flatMap(\.sources))
        var nextRows = articles.filter { showOriginals || !covered.contains($0.id) }
            .map { article in
                TimelineRow(id: .article(article.id), title: article.title, subtitle: article.text,
                            date: article.datePublished ?? article.dateArrived, unread: !article.read,
                            starred: article.starred, isDigest: false)
            }
        if search.isEmpty && sidebarSelection != "starred" {
            for digest in digests where bundled.contains(digest.feed)
                && (selectedFeed == nil || selectedFeed?.id == digest.feed)
                && (folderFeedKeys == nil || folderFeedKeys?.contains(digest.feed) == true) {
                let unread = digestUnread[digest.id] == true
                if sidebarSelection == "unread" && !unread { continue }
                let feedTitle = feeds.first { $0.id == digest.feed }?.title ?? "Feed"
                nextRows.append(TimelineRow(id: .digest(digest.id), title: feedTitle + " · Tagesübersicht",
                                           subtitle: "\(digest.sources.count) Originalbeiträge", date: digest.day,
                                           unread: unread, starred: false, isDigest: true))
            }
        }
        rows = nextRows.sorted { $0.date > $1.date }
    }

    public func loadMore() async { limit += 200; await reload() }

    public func openLatestDigest() {
        guard case .digest(let id) = selection else { return }
        displayedDigest = digests.first { $0.id == id }
    }

    public func loadSelectedArticle() async {
        guard case .article(let key) = selection else { detailArticle = nil; return }
        do {
            let article = try await services.repository.article(key)
            guard selection == .article(key) else { return }
            detailArticle = article
        } catch { if selection == .article(key) { errorMessage = error.localizedDescription } }
    }

    public func observeChanges() async {
        let changes = await services.repository.changes()
        for await _ in changes {
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    public func refresh() async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            try await services.refreshIfNeeded(force: true)
            await reload()
            await generateEnabledDigests()
        } catch { errorMessage = error.localizedDescription }
    }

    public func activate() async {
        await reload()
        guard !Task.isCancelled, !syncing, services.client != nil, !accounts.isEmpty else { return }
        syncing = true
        defer { syncing = false }
        do {
            try await services.refreshIfNeeded()
            await reload()
            await generateEnabledDigests()
        } catch { errorMessage = error.localizedDescription }
    }

    public func connect(server: String, username: String, password: String) async throws {
        guard let url = URL(string: server), url.scheme == "https", url.host != nil,
              !username.isEmpty, !password.isEmpty,
              let credentials = services.credentials, let client = services.client else { throw ReaderError.invalidURL }
        let account = accounts.first { $0.serverURL == url && $0.username == username }
            ?? ReaderAccount(serverURL: url, username: username)
        try await credentials.savePassword(password, accountID: account.id)
        try await services.repository.saveAccount(account)
        try await client.refresh(account: account)
        services.didChange()
        await reload()
    }

    public func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) async {
        do {
            try await services.repository.setStatus(keys, field: field, value: value)
            services.didChange()
            await reload()
            if let client = services.client {
                for account in accounts where keys.contains(where: { $0.accountID == account.id }) {
                    try await client.flush(account: account)
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    public func savePreferences(_ preferences: FeedPreferences) async {
        do {
            try await services.repository.savePreferences(preferences)
            services.didChange()
            await reload()
            if preferences.mode == .digest, let feed = feeds.first(where: { $0.id == preferences.id }) {
                await generate(feed)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    public func preferences(for feed: FeedSnapshot) -> FeedPreferences {
        feedPreferences.first { $0.id == feed.id } ?? FeedPreferences(id: feed.id)
    }

    public func generate(_ feed: FeedSnapshot) async {
        guard !generating, let generator = services.digests else { return }
        generating = true
        defer { generating = false }
        do {
            _ = try await generator.generate(feed: feed)
            services.didChange()
            await reload()
        } catch { errorMessage = error.localizedDescription }
    }

    private func generateEnabledDigests() async {
        for feed in feeds where preferences(for: feed).mode == .digest { await generate(feed) }
    }

    public func loadSources(_ digest: DigestSnapshot) async {
        sourceGeneration &+= 1
        let current = sourceGeneration
        loadingSources = true
        sourceArticles = []
        defer { if current == sourceGeneration { loadingSources = false } }
        do {
            var found: [ArticleSnapshot] = []
            for key in digest.sources {
                let article = try await services.repository.article(key)
                guard !Task.isCancelled, current == sourceGeneration else { return }
                if let article { found.append(article) }
            }
            guard current == sourceGeneration else { return }
            sourceArticles = found
        } catch { if current == sourceGeneration { errorMessage = error.localizedDescription } }
    }

    public func extract(_ article: ArticleSnapshot) async {
        guard let url = article.url, let content = services.content else { return }
        let selected = selection
        do {
            let result = try await content.extract(url: url)
            try Task.checkCancellation()
            guard try await services.repository.updateContent(article, html: result.html, text: result.text) else {
                throw ReaderError.staleResult
            }
            services.didChange()
            if selection == selected { await reload() }
        } catch is CancellationError {
        } catch { if selection == selected { errorMessage = error.localizedDescription } }
    }

    public func runMutation(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            services.didChange()
            await reload()
        } catch { errorMessage = error.localizedDescription }
    }
}
