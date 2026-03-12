//
//  InkwellAccountDelegate.swift
//  Account
//
//  Created by Manton Reece on 3/11/26.
//

import Articles
import FeedFinder
import RSCore
import RSDatabase
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

@MainActor final class InkwellAccountDelegate: AccountDelegate {
	let behaviors: AccountBehaviors = [.disallowFolderManagement, .disallowOPMLImports]
	let server: String? = "micro.blog"
	var isOPMLImportInProgress = false

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}
	let refreshProgress = RSProgress()

	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	var accountSettings: AccountSettings? {
		didSet {
			caller.accountSettings = accountSettings
		}
	}

	private let syncDatabase: SyncDatabase
	private let caller: InkwellAPICaller
	private weak var initializedAccount: Account?
	private static let logger = Inkwell.logger

	init(dataFolder: String, transport: Transport?) {
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		if let transport {
			caller = InkwellAPICaller(transport: transport)
		} else {
			let sessionConfiguration = URLSessionConfiguration.default
			sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
			sessionConfiguration.timeoutIntervalForRequest = 60.0
			sessionConfiguration.httpShouldSetCookies = false
			sessionConfiguration.httpCookieAcceptPolicy = .never
			sessionConfiguration.httpMaximumConnectionsPerHost = 1
			sessionConfiguration.httpCookieStorage = nil
			sessionConfiguration.urlCache = nil

			if let userAgentHeaders = UserAgent.headers() {
				sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
			}

			caller = InkwellAPICaller(transport: URLSession(configuration: sessionConfiguration))
		}

		caller.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .bearerAccessToken)
		}

		refreshProgress.reset()
		refreshProgress.addTasks(3)

		do {
			try await refreshAccount(account)
			try await refreshArticlesAndStatuses(account)
		} catch {
			refreshProgress.reset()
			throw AccountError.wrapped(error, account)
		}
	}

	func syncArticleStatus(for account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	func sendArticleStatus(for account: Account) async throws {
		Self.logger.info("Inkwell: Sending article statuses")
		defer {
			Self.logger.info("Inkwell: Finished sending article statuses")
		}

		guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
			return
		}

		let createUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false })
		try await sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries)

		let deleteUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true })
		try await sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries)

		let createStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true })
		try await sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries)

		let deleteStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false })
		try await sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries)
	}

	func refreshArticleStatus(for account: Account) async throws {
		Self.logger.info("Inkwell: Refreshing article statuses")
		var refreshError: Error?

		do {
			let articleIDs = try await caller.retrieveUnreadEntries()
			await syncArticleReadState(account: account, articleIDs: articleIDs)
		} catch {
			refreshError = error
			Self.logger.error("Inkwell: Retrieving unread entries failed: \(error.localizedDescription)")
		}

		do {
			let articleIDs = try await caller.retrieveStarredEntries()
			await syncArticleStarredState(account: account, articleIDs: articleIDs)
		} catch {
			refreshError = error
			Self.logger.error("Inkwell: Retrieving starred entries failed: \(error.localizedDescription)")
		}

		Self.logger.info("Inkwell: Finished refreshing article statuses")
		if let refreshError {
			throw refreshError
		}
	}

	func importOPML(for account: Account, opmlFile: URL) async throws {
		throw AccountError.invalidParameter
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {
		throw AccountError.invalidParameter
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		throw AccountError.invalidParameter
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {
		throw AccountError.invalidParameter
	}

	@discardableResult
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard container is Account else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			let subResult = try await caller.createSubscription(url: urlString)
			switch subResult {
			case .created(let subscription):
				return try await createFeed(account: account, subscription: subscription, name: name, container: container)
			case .multipleChoice(let choices):
				return try await decideBestFeedChoice(account: account, url: urlString, name: name, container: container, choices: choices)
			case .alreadySubscribed:
				throw AccountError.createErrorAlreadySubscribed
			case .notFound:
				throw AccountError.createErrorNotFound
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		guard let subscriptionID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await caller.renameSubscription(subscriptionID: subscriptionID, newName: name)
			feed.editedName = name
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func addFeed(account: Account, feed: Feed, container: Container) async throws {
		guard let account = container as? Account else {
			throw AccountError.invalidParameter
		}

		account.addFeedIfNotInAnyFolder(feed)
	}

	func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		try await deleteSubscription(for: account, with: feed)
	}

	func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard destinationContainer is Account else {
			throw AccountError.invalidParameter
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: Container) async throws {
		guard container is Account else {
			throw AccountError.invalidParameter
		}

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {
		throw AccountError.invalidParameter
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		let articles = try await account.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		initializedAccount = account
		credentials = try? account.retrieveCredentials(type: .bearerAccessToken)
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		let caller = InkwellAPICaller(transport: transport)
		caller.credentials = credentials
		return try await caller.validateCredentials()
	}

	func suspendNetwork() {
		caller.suspend()
	}

	func suspendDatabase() {
		syncDatabase.suspend()
	}

	func resume(account: Account) {
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .bearerAccessToken)
		}
		caller.resume()
		syncDatabase.resume()
	}

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

extension InkwellAccountDelegate: InkwellAPICallerDelegate {
	func inkwellAPICaller(_ caller: InkwellAPICaller, store credentials: Credentials) throws {
		guard let initializedAccount else {
			throw CredentialsError.missingAccessToken
		}

		try initializedAccount.storeCredentials(credentials)
	}
}

private extension InkwellAccountDelegate {
	func refreshAccount(_ account: Account) async throws {
		let subscriptions = try await caller.retrieveSubscriptions()

		BatchUpdate.shared.perform {
			syncFeeds(account, subscriptions)
		}

		refreshProgress.completeTask()
	}

	func refreshArticlesAndStatuses(_ account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
		try await refreshArticles(account)
		try await refreshMissingArticles(account)
		refreshProgress.reset()
	}

	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {
		guard let subscriptions else {
			return
		}
		assert(Thread.isMainThread)

		Self.logger.info("Inkwell: Syncing feeds with \(subscriptions.count) subscriptions")

		let subscriptionFeedIDs = subscriptions.map { String($0.feedID) }

		for feed in account.topLevelFeeds {
			if !subscriptionFeedIDs.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		var subscriptionsToAdd = Set<FeedbinSubscription>()
		for subscription in subscriptions {
			let subscriptionFeedID = String(subscription.feedID)

			if let feed = account.existingFeed(withFeedID: subscriptionFeedID) {
				feed.name = subscription.name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
				feed.externalID = String(subscription.subscriptionID)
				feed.faviconURL = subscription.jsonFeed?.favicon
				feed.iconURL = subscription.jsonFeed?.icon
			} else {
				subscriptionsToAdd.insert(subscription)
			}
		}

		for subscription in subscriptionsToAdd {
			let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
			feed.externalID = String(subscription.subscriptionID)
			account.addFeedToTreeAtTopLevel(feed)
		}
	}

	func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([Int]) async throws -> Void) async throws {
		guard !statuses.isEmpty else {
			return
		}

		var savedError: Error?

		let articleIDs = statuses.compactMap { Int($0.articleID) }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {
			do {
				try await apiCall(articleIDGroup)
				try? await syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup.map(String.init)))
			} catch {
				savedError = error
				Self.logger.error("Inkwell: Article status sync call failed: \(error.localizedDescription)")
				try? await syncDatabase.resetSelectedForProcessing(Set(articleIDGroup.map(String.init)))
			}
		}

		if let savedError {
			throw savedError
		}
	}

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [FeedbinSubscriptionChoice]) async throws -> Feed {
		var orderFound = 0

		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.userEntered : FeedSpecifier.Source.HTMLLink
			orderFound += 1
			return FeedSpecifier(title: choice.name, urlString: choice.url, source: source, orderFound: orderFound)
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			return try await createFeed(for: account, url: bestSpecifier.urlString, name: name, container: container, validateFeed: true)
		} else {
			throw AccountError.invalidParameter
		}
	}

	@discardableResult
	func createFeed(account: Account, subscription: FeedbinSubscription, name: String?, container: Container) async throws -> Feed {
		let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
		feed.externalID = String(subscription.subscriptionID)
		feed.iconURL = subscription.jsonFeed?.icon
		feed.faviconURL = subscription.jsonFeed?.favicon

		try await account.addFeed(feed, container: container)
		if let name {
			try await account.renameFeed(feed, name: name)
		}

		Task {
			try? await initialFeedDownload(account: account, feed: feed)
		}

		return feed
	}

	func initialFeedDownload(account: Account, feed: Feed) async throws -> Feed {
		let (entries, page) = try await caller.retrieveEntries(feedID: feed.feedID)
		try await processEntries(account: account, entries: entries)
		try await refreshArticleStatus(for: account)
		try await refreshArticles(account, page: page, updateFetchDate: nil)
		try await refreshMissingArticles(account)

		return feed
	}

	func refreshArticles(_ account: Account) async throws {
		Self.logger.info("Inkwell: Refreshing articles")

		let (entries, page, updateFetchDate, lastPageNumber) = try await caller.retrieveEntries()

		if let last = lastPageNumber {
			refreshProgress.addTasks(last - 1)
		}

		try await processEntries(account: account, entries: entries)
		refreshProgress.completeTask()

		try await refreshArticles(account, page: page, updateFetchDate: updateFetchDate)
	}

	func refreshMissingArticles(_ account: Account) async throws {
		Self.logger.info("Inkwell: Refreshing missing articles")
		defer {
			refreshProgress.completeTask()
			Self.logger.info("Inkwell: Finished refreshing missing articles")
		}

		var savedError: Error?

		do {
			let fetchedArticleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
			let articleIDs = Array(fetchedArticleIDs)
			let chunkedArticleIDs = articleIDs.chunked(into: 100)

			for chunk in chunkedArticleIDs {
				do {
					let entries = try await caller.retrieveEntries(articleIDs: chunk)
					try await processEntries(account: account, entries: entries)
				} catch {
					savedError = error
					Self.logger.error("Inkwell: Refresh missing articles error: \(error.localizedDescription)")
				}
			}
		} catch {
			savedError = error
			Self.logger.error("Inkwell: Refresh missing articles error: \(error.localizedDescription)")
		}

		if let savedError {
			throw savedError
		}
	}

	func refreshArticles(_ account: Account, page: String?, updateFetchDate: Date?) async throws {
		guard let page else {
			if let lastArticleFetch = updateFetchDate {
				accountSettings?.lastArticleFetchStartTime = lastArticleFetch
				accountSettings?.lastRefreshCompletedDate = Date()
			}
			return
		}

		let (entries, nextPage) = try await caller.retrieveEntries(page: page)

		try await processEntries(account: account, entries: entries)
		refreshProgress.completeTask()

		try await refreshArticles(account, page: nextPage, updateFetchDate: updateFetchDate)
	}

	func processEntries(account: Account, entries: [FeedbinEntry]?) async throws {
		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: \.feedURL).mapValues(Set.init)
		try await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(entries: [FeedbinEntry]?) -> Set<ParsedItem> {
		guard let entries else {
			return []
		}

		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			return ParsedItem(syncServiceID: String(entry.articleID), uniqueID: String(entry.articleID), feedURL: String(entry.feedID), url: entry.url, externalURL: entry.jsonFeed?.jsonFeedExternalURL, title: entry.title, language: nil, contentHTML: entry.contentHTML, contentText: nil, markdown: nil, summary: entry.summary, imageURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: nil)
		}

		return Set(parsedItems)
	}

	func syncArticleReadState(account: Account, articleIDs: [Int]?) async {
		guard let articleIDs else {
			return
		}

		do {
			guard let pendingArticleIDs = try? await syncDatabase.selectPendingReadStatusArticleIDs() else {
				return
			}

			let inkwellUnreadArticleIDs = Set(articleIDs.map(String.init))
			let updatableUnreadArticleIDs = inkwellUnreadArticleIDs.subtracting(pendingArticleIDs)

			let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDsAsync()

			let deltaUnreadArticleIDs = updatableUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
			try await account.markAsUnreadAsync(articleIDs: deltaUnreadArticleIDs)

			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableUnreadArticleIDs)
			try await account.markAsReadAsync(articleIDs: deltaReadArticleIDs)
		} catch {
			Self.logger.error("Inkwell: Sync article read status failed: \(error.localizedDescription)")
		}
	}

	func syncArticleStarredState(account: Account, articleIDs: [Int]?) async {
		guard let articleIDs else {
			return
		}

		do {
			guard let pendingArticleIDs = try? await syncDatabase.selectPendingStarredStatusArticleIDs() else {
				return
			}

			let inkwellStarredArticleIDs = Set(articleIDs.map(String.init))
			let updatableStarredArticleIDs = inkwellStarredArticleIDs.subtracting(pendingArticleIDs)

			let currentStarredArticleIDs = try await account.fetchStarredArticleIDsAsync()

			let deltaStarredArticleIDs = updatableStarredArticleIDs.subtracting(currentStarredArticleIDs)
			try await account.markAsStarredAsync(articleIDs: deltaStarredArticleIDs)

			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableStarredArticleIDs)
			try await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)
		} catch {
			Self.logger.error("Inkwell: Sync article starred status failed: \(error.localizedDescription)")
		}
	}

	func deleteSubscription(for account: Account, with feed: Feed) async throws {
		guard let subscriptionID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await caller.deleteSubscription(subscriptionID: subscriptionID)
		} catch {
			Self.logger.error("Inkwell: Unable to remove feed from Inkwell. Removing locally and continuing processing: \(error.localizedDescription)")
		}

		account.removeAllInstancesOfFeedFromTreeAtAllLevels(feed)
	}
}
