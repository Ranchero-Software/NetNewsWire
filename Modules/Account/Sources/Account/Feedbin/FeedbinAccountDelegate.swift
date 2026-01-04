//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
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

public enum FeedbinAccountDelegateError: String, Error, Sendable {
	case invalidParameter = "There was an invalid parameter passed."
	case unknown = "An unknown error occurred."
}

@MainActor final class FeedbinAccountDelegate: AccountDelegate {
	let behaviors: AccountBehaviors = [.disallowFeedCopyInRootFolder]
	let server: String? = "api.feedbin.com"
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

	weak var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	private let syncDatabase: SyncDatabase
	private let caller: FeedbinAPICaller
	private static let logger = Feedbin.logger

	init(dataFolder: String, transport: Transport?) {
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		if let transport {
			caller = FeedbinAPICaller(transport: transport)
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

			caller = FeedbinAPICaller(transport: URLSession(configuration: sessionConfiguration))
		}

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		refreshProgress.reset()
		refreshProgress.addTasks(5)

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
		Self.logger.info("Feedbin: Sending article statuses")
		defer {
			Self.logger.info("Feedbin: Finished sending article statuses")
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
		Self.logger.info("Feedbin: Refreshing article statuses")
		var refreshError: Error?

		do {
			let articleIDs = try await caller.retrieveUnreadEntries()
			await self.syncArticleReadState(account: account, articleIDs: articleIDs)

		} catch {
			refreshError = error
			Self.logger.error("Feedbin: Retrieving unread entries failed: \(error.localizedDescription)")
		}

		do {
			let articleIDs = try await caller.retrieveStarredEntries()
			await self.syncArticleStarredState(account: account, articleIDs: articleIDs)
		} catch {
			refreshError = error
			Self.logger.error("Feedbin: Retrieving starred entries failed: \(error.localizedDescription)")
		}

		Self.logger.info("Feedbin: Finished refreshing article statuses")
		if let refreshError {
			throw refreshError
		}
	}

	func importOPML(for account: Account, opmlFile: URL) async throws {
		let opmlData = try Data(contentsOf: opmlFile)
		guard !opmlData.isEmpty else {
			return
		}

		Self.logger.info("Feedbin: Did begin importing OPML")
		isOPMLImportInProgress = true
		refreshProgress.addTask()
		defer {
			isOPMLImportInProgress = false
			refreshProgress.completeTask()
		}

		do {
			let importResult = try await caller.importOPML(opmlData: opmlData)
			if importResult.complete {
				Self.logger.info("Feedbin: Finished importing OPML")
			} else {
				// This will retry until success or error.
				try await self.checkImportResult(opmlImportResultID: importResult.importResultID)
			}
		} catch {
			Self.logger.info("Feedbin: OPML import failed: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		guard folder.hasAtLeastOneFeed() else {
			folder.name = name
			return
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await caller.renameTag(oldName: folder.name ?? "", newName: name)
			renameFolderRelationship(for: account, fromName: folder.name ?? "", toName: name)
			folder.name = name
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {
		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.removeFolderFromTree(folder)
			return
		}

		refreshProgress.addTasks(folder.topLevelFeeds.count)

		for feed in folder.topLevelFeeds {
			defer {
				refreshProgress.completeTask()
			}

			if feed.folderRelationship?.count ?? 0 > 1 {
				if let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
					do {
						try await caller.deleteTagging(taggingID: feedTaggingID)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					} catch {
						Self.logger.error("Feedbin: Remove feed error: \(error.localizedDescription)")
					}
				}
			} else {
				if let subscriptionID = feed.externalID {
					do {
						try await caller.deleteSubscription(subscriptionID: subscriptionID)
						account.clearFeedMetadata(feed)
					} catch {
						Self.logger.error("Feedbin: Remove feed error: \(error.localizedDescription)")
					}
				}
			}
		}

		account.removeFolderFromTree(folder)
	}

	@discardableResult
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

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
		// This error should never happen
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

	func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		if feed.folderRelationship?.count ?? 0 > 1 {
			try await deleteTagging(for: account, with: feed, from: container)
		} else {
			try await deleteSubscription(for: account, with: feed, from: container)
		}
	}

	func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		if sourceContainer is Account {
			try await addFeed(account: account, feed: feed, container: destinationContainer)
		} else {
			try await deleteTagging(for: account, with: feed, from: sourceContainer)
			try await addFeed(account: account, feed: feed, container: destinationContainer)
		}
	}

	func addFeed(account: Account, feed: Feed, container: Container) async throws {
		if let folder = container as? Folder, let feedID = Int(feed.feedID) {

			refreshProgress.addTask()
			defer { refreshProgress.completeTask() }

			do {
				let taggingID = try await caller.createTagging(feedID: feedID, name: folder.name ?? "")

				saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
				account.removeFeedFromTreeAtTopLevel(feed)
				folder.addFeedToTreeAtTopLevel(feed)
			} catch {
				throw AccountError.wrapped(error, account)
			}
		} else if let account = container as? Account {
			account.addFeedIfNotInAnyFolder(feed)
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
				Self.logger.error("Feedbin: Restore folder feed error: \(error.localizedDescription)")
			}
		}

		account.addFolderToTree(folder)
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
		credentials = try? account.retrieveCredentials(type: .basic)
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		let caller = FeedbinAPICaller(transport: transport)
		caller.credentials = credentials
		return try await caller.validateCredentials()
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		syncDatabase.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		caller.resume()
		syncDatabase.resume()
	}

	// MARK: - Notifications
	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: Private

private extension FeedbinAccountDelegate {

	func checkImportResult(opmlImportResultID: Int) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.checkImportResult(opmlImportResultID: opmlImportResultID) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func checkImportResult(opmlImportResultID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			while true {
				try? await Task.sleep(for: .seconds(15))

				Self.logger.info("Feedbin: Checking status of OPML import")
				do {
					let importResult = try await self.caller.retrieveOPMLImportResult(importID: opmlImportResultID)

					if let result = importResult, result.complete {
						Self.logger.info("Feedbin: Checking status of OPML import finished successfully")
						self.refreshProgress.completeTask()
						self.isOPMLImportInProgress = false
						completion(.success(()))
						break
					}
				} catch {
					Self.logger.info("Feedbin: Import OPML check failed: \(error.localizedDescription)")
					self.refreshProgress.completeTask()
					self.isOPMLImportInProgress = false
					completion(.failure(error))
					break
				}
			}
		}
	}

	func refreshAccount(_ account: Account) async throws {
		let tags = try await caller.retrieveTags()
		refreshProgress.completeTask()

		let subscriptions = try await caller.retrieveSubscriptions()
		refreshProgress.completeTask()
		forceExpireFolderFeedRelationship(account, tags)

		let taggings = try await caller.retrieveTaggings()
		BatchUpdate.shared.perform {
			syncFolders(account, tags)
			syncFeeds(account, subscriptions)
			syncFeedFolderRelationship(account, taggings)
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

	// This function can be deleted if Feedbin updates their taggings.json service to
	// show a change when a tag is renamed.
	func forceExpireFolderFeedRelationship(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }

		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Feedbin has a tag that we don't have a folder for.  We might not get a new
		// taggings response for it if it is a folder rename.  Force expire the tagging
		// so that we will for sure get the new tagging information.
		tags.forEach { tag in
			if !folderNames.contains(tag.name) {
				accountMetadata?.conditionalGetInfo[FeedbinAPICaller.ConditionalGetKeys.taggings] = nil
			}
		}

	}

	func syncFolders(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing folders \(tags.count) tags")

		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
		if let folders = account.folders {
			folders.forEach { folder in
				if !tagNames.contains(folder.name ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeedToTreeAtTopLevel(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolderFromTree(folder)
				}
			}
		}

		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders Feedbin has, but we don't
		tagNames.forEach { tagName in
			if !folderNames.contains(tagName) {
				_ = account.ensureFolder(with: tagName)
			}
		}

	}

	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {

		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing feeds with \(subscriptions.count) subscriptions")

		let subFeedIds = subscriptions.map { String($0.feedID) }

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
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		var subscriptionsToAdd = Set<FeedbinSubscription>()
		subscriptions.forEach { subscription in

			let subFeedId = String(subscription.feedID)

			if let feed = account.existingFeed(withFeedID: subFeedId) {
				feed.name = subscription.name
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
				feed.externalID = String(subscription.subscriptionID)
				feed.faviconURL = subscription.jsonFeed?.favicon
				feed.iconURL = subscription.jsonFeed?.icon
			} else {
				subscriptionsToAdd.insert(subscription)
			}
		}

		// Actually add subscriptions all in one go, so we don’t trigger various rebuilding things that Account does.
		subscriptionsToAdd.forEach { subscription in
			let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
			feed.externalID = String(subscription.subscriptionID)
			account.addFeedToTreeAtTopLevel(feed)
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ taggings: [FeedbinTagging]?) {

		guard let taggings = taggings else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing taggings with \(taggings.count) taggings")

		// Set up some structures to make syncing easier
		let folderDict = nameToFolderDictionary(with: account.folders)
		let taggingsDict = taggings.reduce([String: [FeedbinTagging]]()) { (dict, tagging) in
			var taggedFeeds = dict
			if var taggedFeed = taggedFeeds[tagging.name] {
				taggedFeed.append(tagging)
				taggedFeeds[tagging.name] = taggedFeed
			} else {
				taggedFeeds[tagging.name] = [tagging]
			}
			return taggedFeeds
		}

		// Sync the folders
		for (folderName, groupedTaggings) in taggingsDict {

			guard let folder = folderDict[folderName] else { return }

			let taggingFeedIDs = groupedTaggings.map { String($0.feedID) }

			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					folder.removeFeedFromTreeAtTopLevel(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addFeedToTreeAtTopLevel(feed)
				}
			}

			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }

			for tagging in groupedTaggings {
				let taggingFeedID = String(tagging.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: String(tagging.taggingID))
					folder.addFeedToTreeAtTopLevel(feed)
				}
			}

		}

		let taggedFeedIDs = Set(taggings.map { String($0.feedID) })

		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}
	}

	func nameToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()
		for folder in folders {
			let name = folder.name ?? ""
			if d[name] == nil {
				d[name] = folder
			}
		}
		return d
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
				try? await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup.map { String($0) }))
			} catch {
				savedError = error
				Self.logger.error("Feedbin: Article status sync call failed: \(error.localizedDescription)")
				try? await self.syncDatabase.resetSelectedForProcessing(Set(articleIDGroup.map { String($0) }))
			}
		}

		if let savedError {
			throw savedError
		}
	}

	func renameFolderRelationship(for account: Account, fromName: String, toName: String) {
		for feed in account.flattenedFeeds() {
			if var folderRelationship = feed.folderRelationship {
				let relationship = folderRelationship[fromName]
				folderRelationship[fromName] = nil
				folderRelationship[toName] = relationship
				feed.folderRelationship = folderRelationship
			}
		}
	}

	func clearFolderRelationship(for feed: Feed, withFolderName folderName: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = nil
			feed.folderRelationship = folderRelationship
		}
	}

	func saveFolderRelationship(for feed: Feed, withFolderName folderName: String, id: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = id
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderName: id]
		}
	}

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [FeedbinSubscriptionChoice]) async throws -> Feed {
		var orderFound = 0

		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.userEntered : FeedSpecifier.Source.HTMLLink
			orderFound += 1
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source, orderFound: orderFound)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			let feed = try await createFeed(for: account, url: bestSpecifier.urlString, name: name, container: container, validateFeed: true)
			return feed
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
		// Download the initial articles
		let (entries, page) = try await caller.retrieveEntries(feedID: feed.feedID)
		try await processEntries(account: account, entries: entries)
		try await refreshArticleStatus(for: account)
		try await refreshArticles(account, page: page, updateFetchDate: nil)
		try await refreshMissingArticles(account)

		return feed
	}

	func refreshArticles(_ account: Account) async throws {
		Self.logger.info("Feedbin: Refreshing articles")

		let (entries, page, updateFetchDate, lastPageNumber) = try await caller.retrieveEntries()

		if let last = lastPageNumber {
			refreshProgress.addTasks(last - 1)
		}

		try await processEntries(account: account, entries: entries)
		refreshProgress.completeTask()

		try await refreshArticles(account, page: page, updateFetchDate: updateFetchDate)
	}

	func refreshMissingArticles(_ account: Account) async throws {
		Self.logger.info("Feedbin: Refreshing missing articles")
		defer {
			refreshProgress.completeTask()
			Self.logger.info("Feedbin: Finished refreshing missing articles")
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
					Self.logger.error("Feedbin: Refresh missing articles error: \(error.localizedDescription)")
				}
			}
		} catch {
			savedError = error
			Self.logger.error("Feedbin: Refresh missing articles error: \(error.localizedDescription)")
		}

		if let savedError {
			throw savedError
		}
	}

	func refreshArticles(_ account: Account, page: String?, updateFetchDate: Date?) async throws {
		guard let page else {
			if let lastArticleFetch = updateFetchDate {
				accountMetadata?.lastArticleFetchStartTime = lastArticleFetch
				accountMetadata?.lastArticleFetchEndTime = Date()
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
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }
		try await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(entries: [FeedbinEntry]?) -> Set<ParsedItem> {
		guard let entries = entries else {
			return Set<ParsedItem>()
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

			let feedbinUnreadArticleIDs = Set(articleIDs.map { String($0) })
			let updatableFeedbinUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(pendingArticleIDs)

			let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDsAsync()

			// Mark articles as unread
			let deltaUnreadArticleIDs = updatableFeedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
			try await account.markAsUnreadAsync(articleIDs: deltaUnreadArticleIDs)

			// Mark articles as read
			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableFeedbinUnreadArticleIDs)
			try await account.markAsReadAsync(articleIDs: deltaReadArticleIDs)
		} catch {
			Self.logger.error("Feedbin: Sync Article Read Status failed: \(error.localizedDescription)")
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

			let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) })
			let updatableFeedbinStarredArticleIDs = feedbinStarredArticleIDs.subtracting(pendingArticleIDs)

			let currentStarredArticleIDs = try await account.fetchStarredArticleIDsAsync()

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableFeedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
			try await account.markAsStarredAsync(articleIDs: deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableFeedbinStarredArticleIDs)
			try await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)
		} catch {
			Self.logger.error("Feedbin: Sync Article Starred Status failed: \(error.localizedDescription)")
		}
	}

	func deleteTagging(for account: Account, with feed: Feed, from container: Container?) async throws {
		if let folder = container as? Folder, let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
			refreshProgress.addTask()
			defer {
				refreshProgress.completeTask()
			}

			do {
				try await caller.deleteTagging(taggingID: feedTaggingID)
				clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
				folder.removeFeedFromTreeAtTopLevel(feed)
				account.addFeedIfNotInAnyFolder(feed)
			} catch {
				throw AccountError.wrapped(error, account)
			}
		} else {
			if let account = container as? Account {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}
	}

	func deleteSubscription(for account: Account, with feed: Feed, from container: Container?) async throws {
		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await caller.deleteSubscription(subscriptionID: subscriptionID)
		} catch {
			Self.logger.error("Feedbin: Unable to remove feed from Feedbin. Removing locally and continuing processing: \(error.localizedDescription)")
		}

		account.clearFeedMetadata(feed)
		account.removeAllInstancesOfFeedFromTreeAtAllLevels(feed)
	}
}
