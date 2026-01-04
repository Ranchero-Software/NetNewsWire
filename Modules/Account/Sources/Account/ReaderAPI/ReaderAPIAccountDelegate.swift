//
//  ReaderAPIAccountDelegate.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSParser
import RSWeb
import FeedFinder
import SyncDatabase
import os.log
import Secrets

public enum ReaderAPIAccountDelegateError: LocalizedError {
	case unknown
	case invalidParameter
	case invalidResponse
	case urlNotFound

	public var errorDescription: String? {
		switch self {
		case .unknown:
			return NSLocalizedString("An unexpected error occurred.", comment: "An unexpected error occurred.")
		case .invalidParameter:
			return NSLocalizedString("An invalid parameter was passed.", comment: "An invalid parameter was passed.")
		case .invalidResponse:
			return NSLocalizedString("There was an invalid response from the server.", comment: "There was an invalid response from the server.")
		case .urlNotFound:
			return NSLocalizedString("The API URL wasn't found.", comment: "The API URL wasn't found.")
		}
	}
}

final class ReaderAPIAccountDelegate: AccountDelegate {

	private let variant: ReaderAPIVariant

	private let syncDatabase: SyncDatabase

	private let caller: ReaderAPICaller
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ReaderAPI")

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}
	let refreshProgress = RSProgress()

	var behaviors: AccountBehaviors {
		var behaviors: AccountBehaviors = [.disallowOPMLImports, .disallowFeedInMultipleFolders]
		if variant == .freshRSS {
			behaviors.append(.disallowFeedInRootFolder)
		}
		return behaviors
	}

	@MainActor var server: String? {
		caller.server
	}

	var isOPMLImportInProgress = false

	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	weak var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	init(dataFolder: String, transport: Transport?, variant: ReaderAPIVariant) {
		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databasePath)

		if transport != nil {
			self.caller = ReaderAPICaller(transport: transport!)
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

			self.caller = ReaderAPICaller(transport: URLSession(configuration: sessionConfiguration))
		}

		self.caller.variant = variant
		self.variant = variant

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll(for account: Account) async throws {

		refreshProgress.addTasks(6)

		do {
			try await refreshAccount(account)

			try await sendArticleStatus(for: account)
			refreshProgress.completeTask()

			let articleIDs = try await caller.retrieveItemIDs(type: .allForAccount)
			refreshProgress.completeTask()

			_ = try? await account.markAsReadAsync(articleIDs: Set(articleIDs))
			try? await refreshArticleStatus(for: account)
			refreshProgress.completeTask()

			await refreshMissingArticles(account)
			refreshProgress.reset()

		} catch {
			refreshProgress.reset()

			let wrappedError = AccountError.wrapped(error, account)
			if wrappedError.isCredentialsError, let basicCredentials = try? account.retrieveCredentials(type: .readerBasic), let endpoint = account.endpointURL {

				self.caller.credentials = basicCredentials

				do {
					if let apiCredentials = try await caller.validateCredentials(endpoint: endpoint) {
						try? account.storeCredentials(apiCredentials)
						caller.credentials = apiCredentials
						try await refreshAll(for: account)
						return
					}
					throw wrappedError
				} catch {
					throw wrappedError
				}

			} else {
				throw wrappedError
			}
		}
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		guard variant != .inoreader else {
			return
		}

		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	public func sendArticleStatus(for account: Account) async throws {

		Self.logger.info("ReaderAPI: Sending article statuses")

		let syncStatuses = (try await self.syncDatabase.selectForProcessing()) ?? Set<SyncStatus>()

		let createUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false }
		let deleteUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true }
		let createStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true }
		let deleteStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false }

		await sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries)
		await sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries)
		await sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries)
		await sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries)

		Self.logger.info("ReaderAPI: finished sending article statuses")
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
		Self.logger.info("ReaderAPI: Refreshing article statuses")

		var errorOccurred = false

		let articleIDs = try await caller.retrieveItemIDs(type: .unread)

		do {
			try await syncArticleReadState(account: account, articleIDs: articleIDs)
		} catch {
			errorOccurred = true
			Self.logger.error("ReaderAPI: Retrieving unread entries failed: \(error.localizedDescription)")
		}

		do {
			let articleIDs = try await caller.retrieveItemIDs(type: .starred)
			await syncArticleStarredState(account: account, articleIDs: articleIDs)
		} catch {
			errorOccurred = true
				Self.logger.error("ReaderAPI: Retrieving starred entries failed: \(error.localizedDescription)")
		}

		Self.logger.info("ReaderAPI: Finished refreshing article statuses")
		if errorOccurred {
			throw AccountError.unknown
		}
	}

	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await caller.renameTag(oldName: folder.name ?? "", newName: name)
			folder.externalID = "user/-/label/\(name)"
			folder.name = name
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {

		for feed in folder.topLevelFeeds {

			if feed.folderRelationship?.count ?? 0 > 1 {

				if let subscriptionID = feed.externalID {

					refreshProgress.addTask()

					do {
						try await caller.deleteTagging(subscriptionID: subscriptionID, tagName: folder.nameForDisplay)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
						refreshProgress.completeTask()
					} catch {
						refreshProgress.completeTask()
						Self.logger.error("ReaderAPI: Remove feed error: \(error.localizedDescription)")
					}
				}

			} else {

				if let subscriptionID = feed.externalID {
					refreshProgress.addTask()

					do {
						try await caller.deleteSubscription(subscriptionID: subscriptionID)
						account.clearFeedMetadata(feed)

						refreshProgress.completeTask()
					} catch {

						refreshProgress.completeTask()
						Self.logger.error("ReaderAPI: Remove feed error: \(error.localizedDescription)")
					}
				}
			}
		}

		if self.variant == .theOldReader {
			account.removeFolderFromTree(folder)
		} else {
			if let folderExternalID = folder.externalID {
				try await caller.deleteTag(folderExternalID: folderExternalID)
			}
			account.removeFolderFromTree(folder)
		}
	}

	@discardableResult
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		guard let url = URL(string: url) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTasks(2)

		do {

			let feedSpecifiers = try await FeedFinder.find(url: url)
			refreshProgress.completeTask()

			let filteredFeedSpecifiers = feedSpecifiers.filter { !$0.urlString.contains("json") }
			guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: filteredFeedSpecifiers) else {
				refreshProgress.reset()
				throw AccountError.createErrorNotFound
			}

			let subResult = try await caller.createSubscription(url: bestFeedSpecifier.urlString, name: name)
			refreshProgress.completeTask()

			switch subResult {
			case .created(let subscription):
				return try await createFeed(account: account, subscription: subscription, name: name, container: container)
			case .notFound:
				throw AccountError.createErrorNotFound
			}

		} catch {
			refreshProgress.reset()
			throw AccountError.createErrorNotFound
		}
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			assert(feed.externalID != nil)
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()

		do {
			try await caller.renameSubscription(subscriptionID: subscriptionID, newName: name)
			feed.editedName = name
			refreshProgress.completeTask()
		} catch {
			refreshProgress.completeTask()
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFeed(account: Account, feed: Feed, container: any Container) async throws {
		guard let subscriptionID = feed.externalID else {
			assert(feed.externalID != nil)
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask()}

		do {
			try await caller.deleteSubscription(subscriptionID: subscriptionID)
			account.clearFeedMetadata(feed)
			account.removeAllInstancesOfFeedFromTreeAtAllLevels(feed)
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {

		if sourceContainer is Account {
			try await addFeed(account: account, feed: feed, container: destinationContainer)
		} else {

			guard
				let subscriptionID = feed.externalID,
				let sourceTag = (sourceContainer as? Folder)?.name,
				let destinationTag = (destinationContainer as? Folder)?.name
			else {
				throw AccountError.invalidParameter
			}

			refreshProgress.addTask()
			defer { refreshProgress.completeTask() }

			do {
				try await caller.moveSubscription(subscriptionID: subscriptionID, sourceTag: sourceTag, destinationTag: destinationTag)
				sourceContainer.removeFeedFromTreeAtTopLevel(feed)
				destinationContainer.addFeedToTreeAtTopLevel(feed)
			} catch {
				throw error
			}
		}
	}

	func addFeed(account: Account, feed: Feed, container: any Container) async throws {

		if let folder = container as? Folder, let feedExternalID = feed.externalID {

			refreshProgress.addTask()

			do {

				try await caller.createTagging(subscriptionID: feedExternalID, tagName: folder.name ?? "")

				self.saveFolderRelationship(for: feed, folderExternalID: folder.externalID, feedExternalID: feedExternalID)
				account.removeFeedFromTreeAtTopLevel(feed)
				folder.addFeedToTreeAtTopLevel(feed)

				refreshProgress.completeTask()

			} catch {

				refreshProgress.completeTask()
				throw AccountError.wrapped(error, account)
			}
		} else {

			if let account = container as? Account {
				account.addFeedIfNotInAnyFolder(feed)
			}
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {

		for feed in folder.topLevelFeeds {

			folder.topLevelFeeds.remove(feed)

			do {
				try await restoreFeed(for: account, feed: feed, container: folder)
			} catch {
				Self.logger.error("ReaderAPI: Restore folder feed error: \(error.localizedDescription)")
				}
		}

		account.addFolderToTree(folder)
	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		let articles = try await account.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try await syncDatabase.selectPendingCount(), count > 100 {
			try? await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .readerAPIKey)
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		guard let endpoint else {
			throw TransportError.noURL
		}

		let caller = ReaderAPICaller(transport: transport)
		caller.credentials = credentials
		return try await caller.validateCredentials(endpoint: endpoint)
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.cancelAll()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		syncDatabase.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		syncDatabase.resume()
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: Private

private extension ReaderAPIAccountDelegate {

	@MainActor func refreshAccount(_ account: Account) async throws {

		let tags = try await caller.retrieveTags()
		refreshProgress.completeTask()

		let subscriptions = try await caller.retrieveSubscriptions()
		refreshProgress.completeTask()

		BatchUpdate.shared.perform {
			self.syncFolders(account, tags)
			self.syncFeeds(account, subscriptions)
			self.syncFeedFolderRelationship(account, subscriptions)
		}
	}

	@MainActor func syncFolders(_ account: Account, _ tags: [ReaderAPITag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		let folderTags: [ReaderAPITag]
		if variant == .inoreader {
			folderTags = tags.filter { $0.type == "folder" }
		} else {
			folderTags = tags.filter { $0.tagID.contains("/label/") }
		}

		guard !folderTags.isEmpty else { return }

		Self.logger.info("ReaderAPI: Syncing folders with \(folderTags.count) tags")

		let readerFolderExternalIDs = folderTags.compactMap { $0.tagID }

		// Delete any folders not at Reader
		if let folders = account.folders {
			folders.forEach { folder in
				if !readerFolderExternalIDs.contains(folder.externalID ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeedToTreeAtTopLevel(feed)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					}
					account.removeFolderFromTree(folder)
				}
			}
		}

		let folderExternalIDs: [String] =  {
			if let folders = account.folders {
				return folders.compactMap { $0.externalID }
			} else {
				return [String]()
			}
		}()

		// Make any folders Reader has, but we don't
		folderTags.forEach { tag in
			if !folderExternalIDs.contains(tag.tagID) {
				let folder = account.ensureFolder(with: tag.folderName ?? "None")
				folder?.externalID = tag.tagID
			}
		}

	}

	@MainActor func syncFeeds(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {

		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		Self.logger.info("ReaderAPI: Syncing feeds with \(subscriptions.count) subscriptions")

		let subFeedIds = subscriptions.map { $0.feedID }

		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						folder.removeFeedFromTreeAtTopLevel(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				account.clearFeedMetadata(feed)
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in

			if let feed = account.existingFeed(withFeedID: subscription.feedID) {
				feed.name = subscription.name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: subscription.feedID, homePageURL: subscription.homePageURL)
				feed.externalID = subscription.feedID
				account.addFeedToTreeAtTopLevel(feed)
			}

		}

	}

	func syncFeedFolderRelationship(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)
		Self.logger.info("ReaderAPI: Syncing taggings with \(subscriptions.count) subscriptions")

		// Set up some structures to make syncing easier
		let folderDict = externalIDToFolderDictionary(with: account.folders)
		let taggingsDict = subscriptions.reduce([String: [ReaderAPISubscription]]()) { (dict, subscription) in
			var taggedFeeds = dict

			subscription.categories.forEach({ (category) in
				if var taggedFeed = taggedFeeds[category.categoryId] {
					taggedFeed.append(subscription)
					taggedFeeds[category.categoryId] = taggedFeed
				} else {
					taggedFeeds[category.categoryId] = [subscription]
				}
			})

			return taggedFeeds
		}

		// Sync the folders
		for (folderExternalID, groupedTaggings) in taggingsDict {
			guard let folder = folderDict[folderExternalID] else { return }
			let taggingFeedIDs = groupedTaggings.map { $0.feedID }

			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					folder.removeFeedFromTreeAtTopLevel(feed)
					clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					account.addFeedToTreeAtTopLevel(feed)
				}
			}

			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }

			for subscription in groupedTaggings {
				let taggingFeedID = subscription.feedID
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, folderExternalID: folderExternalID, feedExternalID: subscription.feedID)
					folder.addFeedToTreeAtTopLevel(feed)
				}
			}

		}

		let taggedFeedIDs = Set(subscriptions.filter({ !$0.categories.isEmpty }).map { String($0.feedID) })

		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}
	}

	func externalIDToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()

		for folder in folders {
			if let externalID = folder.externalID, d[externalID] == nil {
				d[externalID] = folder
			}
		}

		return d
	}

	func sendArticleStatuses(_ statuses: Set<SyncStatus>, apiCall: ([String]) async throws -> Void) async {
		guard !statuses.isEmpty else {
			return
		}

		let articleIDs = statuses.compactMap { $0.articleID }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {

			do {
				_ = try await apiCall(articleIDGroup)
				try? await syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup))
			} catch {
				Self.logger.error("ReaderAPI: Article status sync call failed: \(error.localizedDescription)")
				try? await syncDatabase.resetSelectedForProcessing(Set(articleIDGroup))
			}
		}
	}

	func clearFolderRelationship(for feed: Feed, folderExternalID: String?) {
		guard var folderRelationship = feed.folderRelationship, let folderExternalID = folderExternalID else { return }
		folderRelationship[folderExternalID] = nil
		feed.folderRelationship = folderRelationship
	}

	func saveFolderRelationship(for feed: Feed, folderExternalID: String?, feedExternalID: String) {
		guard let folderExternalID = folderExternalID else { return }
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderExternalID] = feedExternalID
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderExternalID: feedExternalID]
		}
	}

	@MainActor func createFeed(account: Account, subscription: ReaderAPISubscription, name: String?, container: Container) async throws -> Feed {

		let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
		feed.externalID = String(subscription.feedID)

		try await account.addFeed(feed, container: container)
		if let name {
			try await renameFeed(for: account, with: feed, to: name)
		}
		try await initialFeedDownload(account: account, feed: feed)

		return feed
	}

	@discardableResult
	func initialFeedDownload( account: Account, feed: Feed) async throws -> Feed {

		refreshProgress.addTasks(5)

		// Download the initial articles
		let articleIDs = try await caller.retrieveItemIDs(type: .allForFeed, feedID: feed.feedID)

		refreshProgress.completeTask()

		_ = try? await account.markAsReadAsync(articleIDs: Set(articleIDs))
		refreshProgress.completeTask()

		try? await refreshArticleStatus(for: account)
		refreshProgress.completeTask()

		await refreshMissingArticles(account)
		refreshProgress.reset()

		return feed
	}

	func refreshMissingArticles(_ account: Account) async {

		do {
			let fetchedArticleIDs = (try? await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()) ?? Set<String>()

			if fetchedArticleIDs.isEmpty {
				return
			}

			Self.logger.info("ReaderAPI: Refreshing missing articles")

			let articleIDs = Array(fetchedArticleIDs)
			let chunkedArticleIDs = articleIDs.chunked(into: 150)

			refreshProgress.addTasks(chunkedArticleIDs.count + 1)

			for chunk in chunkedArticleIDs {

				do {
					let entries = try await caller.retrieveEntries(articleIDs: chunk)
					refreshProgress.completeTask()
					await processEntries(account: account, entries: entries)
				} catch {
					Self.logger.error("ReaderAPI: Refresh missing articles error: \(error.localizedDescription)")
				}
			}

			refreshProgress.completeTask()
			Self.logger.info("ReaderAPI: Finished refreshing missing articles")
		}
	}

	func processEntries(account: Account, entries: [ReaderAPIEntry]?) async {

		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }

		try? await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(account: Account, entries: [ReaderAPIEntry]?) -> Set<ParsedItem> {

		guard let entries = entries else {
			return Set<ParsedItem>()
		}

		let parsedItems: [ParsedItem] = entries.compactMap { entry in
			guard let streamID = entry.origin.streamId else {
				return nil
			}

			var authors: Set<ParsedAuthor>? {
				guard let name = entry.author else {
					return nil
				}
				return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
			}

			return ParsedItem(syncServiceID: entry.uniqueID(variant: variant),
							  uniqueID: entry.uniqueID(variant: variant),
							  feedURL: streamID,
							  url: nil,
							  externalURL: entry.alternates?.first?.url,
							  title: entry.title,
							  language: nil,
							  contentHTML: entry.summary.content,
							  contentText: nil,
							  markdown: nil,
							  summary: entry.summary.content,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: entry.parseDatePublished(),
							  dateModified: nil,
							  authors: authors,
							  tags: nil,
							  attachments: nil)
		}

		return Set(parsedItems)

	}

	func syncArticleReadState(account: Account, articleIDs: [String]?) async throws {

		guard let articleIDs else {
			return
		}

		Task { @MainActor in
			do {

				let pendingArticleIDs = (try await self.syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()

				let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)

				let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDsAsync()

				// Mark articles as unread
				let deltaUnreadArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
				_ = try? await account.markAsUnreadAsync(articleIDs: deltaUnreadArticleIDs)

				// Mark articles as read
				let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
				_ = try? await account.markAsReadAsync(articleIDs: deltaReadArticleIDs)

			} catch {
				Self.logger.error("Sync Article read status error: \(error.localizedDescription)")
			}
		}
	}

	func syncArticleStarredState(account: Account, articleIDs: [String]?) async {

		guard let articleIDs else {
			return
		}

		do {

			let pendingArticleIDs = (try await self.syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()

			let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)

			let currentStarredArticleIDs = try await account.fetchStarredArticleIDsAsync()

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentStarredArticleIDs)
			_ = try? await account.markAsStarredAsync(articleIDs: deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
			_ = try? await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)

		} catch {
			Self.logger.error("Sync Article starred status error: \(error.localizedDescription)")
		}
	}
}
