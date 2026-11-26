//
//  MinifluxAccountDelegate.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import FeedFinder
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os
import Secrets

@MainActor final class MinifluxAccountDelegate: AccountDelegate {
	weak var account: Account?
	let behaviors: AccountBehaviors = [.disallowFeedInRootFolder, .disallowFeedInMultipleFolders]
	var isOPMLImportInProgress = false

	var server: String? {
		caller.server
	}

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
	private let caller: MinifluxAPICaller
	/// Overlapping sends would select the same rows, and the starred fallback toggles, so two sends would undo each other.
	private var isSendingArticleStatus = false
	private static let logger = Miniflux.logger
	/// Send statuses immediately once this many are queued, rather than waiting for the next scheduled sync.
	private static let sendStatusBatchThreshold = 100
	/// `changed_after` is compared against the server’s clock, so back it up to cover a device clock that runs ahead.
	private static let changedAfterClockSkewMargin: TimeInterval = 5 * 60
	/// How far back to fetch articles when there’s no changed_after date.
	private static let articleHistoryMonths = 3
	/// Missing articles are fetched one request per entry, so each refresh fetches at most this many.
	private static let missingArticlesFetchLimit = 250
	/// Fetched entries are saved, and deleted statuses removed, after each chunk of this many.
	private static let missingArticlesChunkSize = 50
	/// Categories, feeds, local folder and feed sync, the first article page, and missing articles.
	private static let refreshAllTaskCount = 5
	/// Finding the feed and creating it on the server.
	private static let createFeedTaskCount = 2

	init(dataFolder: String) {
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databaseFilePath)
		caller = MinifluxAPICaller()

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		retrieveCredentialsIfNeeded(account)

		refreshProgress.reset()
		refreshProgress.addTasks(Self.refreshAllTaskCount)

		do {
			try await account.logActivity(kind: .refreshAll) {
				try await refreshAccount(account)
				try await refreshArticlesAndStatuses(account)
			}
		} catch {
			refreshProgress.reset()
			throw AccountError.wrapped(error, account)
		}
	}

	func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}
		let sentCount = try await sendArticleStatusReturningCount(for: account)
		let changedStatusCount = try await refreshArticles(account)
		return sentCount > 0 || changedStatusCount > 0
	}

	func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await sendArticleStatusReturningCount(for: account)
	}

	/// Sends queued local status changes upstream. Returns the count successfully sent.
	private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		guard !isSendingArticleStatus else {
			Self.logger.info("Miniflux: Skipping article status send because one is in progress")
			return 0
		}
		isSendingArticleStatus = true
		Self.logger.info("Miniflux: Sending article statuses")
		defer {
			isSendingArticleStatus = false
			Self.logger.info("Miniflux: Finished sending article statuses")
		}

		do {
			return try await account.logActivity(kind: .sendArticleStatuses) { () -> Int in
				guard let syncStatuses = try? await syncDatabase.selectForProcessing() else {
					Self.logger.error("Miniflux: Sync database selectForProcessing failed")
					return 0
				}

				var sentCount = 0
				var savedError: Error?

				for (key, flag) in [(SyncStatus.Key.read, true), (.read, false), (.starred, true), (.starred, false)] {
					do {
						sentCount += try await sendEntryStatuses(pendingEntryIDs(in: syncStatuses, key: key, flag: flag), key: key) { entryIDs in
							if key == .read {
								try await caller.updateEntries(entryIDs: entryIDs, read: flag)
							} else {
								try await caller.updateEntries(entryIDs: entryIDs, starred: flag)
							}
						}
					} catch {
						savedError = error
					}
				}

				if let savedError {
					throw savedError
				}
				return sentCount
			}
		} catch {
			account.postSyncError(error, operation: "Sending article status")
			throw error
		}
	}

	/// Statuses come with the changed_after entries fetch, so this is the same as refreshing articles.
	func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await refreshArticles(account)
	}

	/// Reconciles against the server’s full unread and starred ID sets. Returns the number of statuses changed.
	private func reconcileAllArticleStatuses(for account: Account) async throws -> Int {
		Self.logger.info("Miniflux: Refreshing article statuses")

		return try await account.logActivity(kind: .refreshArticleStatuses) { () -> Int in
			var changedCount = 0
			var refreshError: Error?

			async let pendingUnreadEntryIDs = caller.retrieveUnreadEntryIDs()
			async let pendingStarredEntryIDs = caller.retrieveStarredEntryIDs()

			do {
				let entryIDs = try await pendingUnreadEntryIDs
				changedCount += await self.syncArticleReadState(account: account, entryIDs: entryIDs)
			} catch {
				refreshError = error
				Self.logger.error("Miniflux: Retrieving unread entries failed: \(error.localizedDescription)")
			}

			do {
				let entryIDs = try await pendingStarredEntryIDs
				changedCount += await self.syncArticleStarredState(account: account, entryIDs: entryIDs)
			} catch {
				refreshError = error
				Self.logger.error("Miniflux: Retrieving starred entries failed: \(error.localizedDescription)")
			}

			Self.logger.info("Miniflux: Finished refreshing article statuses")
			if let refreshError {
				account.postSyncError(refreshError, operation: "Refreshing article status")
				throw refreshError
			}
			return changedCount
		}
	}

	func importOPML(opmlFile: URL) async throws {
		guard let account else {
			return
		}
		let opmlData = try Data(contentsOf: opmlFile)
		guard !opmlData.isEmpty else {
			return
		}

		Self.logger.info("Miniflux: Did begin importing OPML")
		isOPMLImportInProgress = true
		refreshProgress.addTask()
		defer {
			isOPMLImportInProgress = false
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .importOPML, detail: opmlFile.lastPathComponent) {
				try await caller.importOPML(opmlData: opmlData)
				Self.logger.info("Miniflux: Finished importing OPML")
			}
		} catch {
			Self.logger.error("Miniflux: OPML import failed: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		guard !name.isEmpty else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			return try await account.logActivity(kind: .createFolder, detail: name) {
				let category = try await caller.createCategory(title: name)
				guard let folder = account.ensureFolder(with: name) else {
					throw AccountError.invalidParameter
				}
				folder.externalID = String(category.categoryID)
				return folder
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		guard let externalID = folder.externalID, let categoryID = Int(externalID) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .renameFolder, detail: folder.name) {
				try await caller.renameCategory(categoryID: categoryID, title: name)
				folder.name = name
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFolder(with folder: Folder) async throws {
		guard let account else {
			return
		}
		guard let externalID = folder.externalID, let categoryID = Int(externalID) else {
			throw AccountError.invalidParameter
		}

		do {
			try await account.logActivity(kind: .removeFolder, detail: folder.name) {
				refreshProgress.addTasks(folder.topLevelFeeds.count)

				for feed in folder.topLevelFeeds {
					defer {
						refreshProgress.completeTask()
					}

					guard let feedExternalID = feed.externalID, let feedID = Int(feedExternalID) else {
						continue
					}
					do {
						try await caller.deleteFeed(feedID: feedID)
						account.clearFeedSettings(feed)
					} catch {
						Self.logger.error("Miniflux: Remove feed error: \(error.localizedDescription)")
						account.postSyncError(error, operation: "Removing feed")
					}
				}

				// Miniflux won’t delete a category that still has feeds, so remove the folder locally only after the server does.
				try await caller.deleteCategory(categoryID: categoryID)
				account.removeFolderFromTree(folder)
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	@discardableResult
	func createFeed(url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTasks(Self.createFeedTaskCount)
		var uncompletedTasks = Self.createFeedTaskCount
		defer {
			while uncompletedTasks > 0 {
				refreshProgress.completeTask()
				uncompletedTasks -= 1
			}
		}

		do {
			return try await account.logActivity(kind: .subscribeFeed, detail: url.absoluteString) {
				let feedSpecifiers = try await FeedFinder.find(url: url)
				refreshProgress.completeTask()
				uncompletedTasks -= 1

				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers) else {
					throw AccountError.createErrorNotFound
				}

				let categoryID = try await categoryID(for: container)
				let feedID = try await caller.createFeed(url: bestFeedSpecifier.urlString, categoryID: categoryID)
				refreshProgress.completeTask()
				uncompletedTasks -= 1

				return try await createFeed(account: account, feedID: feedID, name: name, categoryID: categoryID)
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		guard let externalID = feed.externalID, let feedID = Int(externalID) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				try await caller.renameFeed(feedID: feedID, title: name)
				feed.editedName = name
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		guard let externalID = feed.externalID, let feedID = Int(externalID) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .removeFeed, detail: feed.url) {
				try await caller.deleteFeed(feedID: feedID)
				account.clearFeedSettings(feed)
				account.removeAllInstancesOfFeedFromTreeAtAllLevels(feed)
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		guard
			let feedExternalID = feed.externalID,
			let feedID = Int(feedExternalID),
			let destinationExternalID = (destinationContainer as? Folder)?.externalID,
			let destinationCategoryID = Int(destinationExternalID)
		else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .moveFeed, detail: feed.url) {
				try await caller.moveFeed(feedID: feedID, categoryID: destinationCategoryID)
				sourceContainer.removeFeedFromTreeAtTopLevel(feed)
				destinationContainer.addFeedToTreeAtTopLevel(feed)
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func addFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .addFeed, detail: feed.url) {
			if let folder = container as? Folder {
				guard
					let feedExternalID = feed.externalID,
					let feedID = Int(feedExternalID),
					let folderExternalID = folder.externalID,
					let destinationCategoryID = Int(folderExternalID)
				else {
					throw AccountError.invalidParameter
				}

				refreshProgress.addTask()
				defer {
					refreshProgress.completeTask()
				}

				do {
					try await caller.moveFeed(feedID: feedID, categoryID: destinationCategoryID)
					// A Miniflux feed has one category, so the move takes it out of every other folder.
					account.removeFeedFromTreeAtTopLevel(feed)
					for otherFolder in account.folders ?? [] where otherFolder !== folder {
						otherFolder.removeFeedFromTreeAtTopLevel(feed)
					}
					folder.addFeedToTreeAtTopLevel(feed)
				} catch {
					throw AccountError.wrapped(error, account)
				}
			} else if let containerAccount = container as? Account {
				containerAccount.addFeedIfNotInAnyFolder(feed)
			}
		}
	}

	func restoreFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			try await createFeed(url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(folder: Folder) async throws {
		guard let account else {
			return
		}
		guard let folderName = folder.name, !folderName.isEmpty else {
			throw AccountError.invalidParameter
		}
		do {
			try await account.logActivity(kind: .restoreFolder, detail: folderName) {
				// The category was deleted on the server along with the folder, so re-create it before restoring its feeds.
				do {
					let category = try await caller.createCategory(title: folderName)
					folder.externalID = String(category.categoryID)
				} catch {
					Self.logger.error("Miniflux: Restore folder category error: \(error.localizedDescription)")
					throw error
				}

				// The folder goes in the tree first, so each restored feed finds it by externalID.
				let feeds = folder.topLevelFeeds
				folder.topLevelFeeds.removeAll()
				account.addFolderToTree(folder)

				for feed in feeds {
					do {
						try await restoreFeed(feed: feed, container: folder)
					} catch {
						Self.logger.error("Miniflux: Restore folder feed error: \(error.localizedDescription)")
						account.postSyncError(error, operation: "Restoring feed")
					}
				}
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		guard let account else {
			return
		}
		let changedArticleIDs = await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(changedArticleIDs.map { articleID in
			SyncStatus(articleID: articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		await syncDatabase.insertStatuses(syncStatuses)
		if !syncStatuses.isEmpty {
			NotificationCenter.default.post(name: .AccountDidQueueArticleStatuses, object: account)
		}
		if let count = try? await syncDatabase.selectPendingCount(), count > Self.sendStatusBatchThreshold {
			// Flush in the background so marking doesn't block the caller
			// <https://github.com/Ranchero-Software/NetNewsWire/issues/5273>
			Task { try? await sendArticleStatus() }
		}
	}

	func accountDidInitialize() {
		guard let account else {
			return
		}
		retrieveCredentialsIfNeeded(account)

		// Clear statuses left selected by a send that was in progress when the app quit.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4280>
		syncDatabase.resetAllSelectedForProcessing()
	}

	func accountWillBeDeleted() {
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		guard let endpoint else {
			throw WebserviceError.noURL
		}

		let caller = MinifluxAPICaller()
		caller.credentials = credentials
		return try await caller.validateCredentials(endpoint: endpoint)
	}

	func vacuumDatabases() async {
		guard let account else {
			return
		}
		await account.logActivity(kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(syncDatabase.databasePath)) {
			await syncDatabase.vacuum()
		}
	}

	// MARK: Suspend and Resume

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Resume network activity after a previous `suspendNetwork()`.
	func resume() {
		if let account {
			retrieveCredentialsIfNeeded(account)
		}
		caller.resume()
	}

	// MARK: - Notifications
	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: Private

private extension MinifluxAccountDelegate {

	func retrieveCredentialsIfNeeded(_ account: Account) {
		guard credentials == nil else {
			return
		}
		credentials = (try? account.retrieveCredentials(type: .minifluxAPIToken)) ?? (try? account.retrieveCredentials(type: .minifluxBasic))
	}

	func refreshAccount(_ account: Account) async throws {
		do {
			try await account.logActivity(kind: .refreshFeedList, successMessage: { "\($0.feeds) feeds, \($0.folders) folders" }, { () -> (folders: Int, feeds: Int) in
				await self.caller.detectServerVersion()

				async let pendingCategories = self.caller.retrieveCategories()
				async let pendingFeeds = self.caller.retrieveFeeds()

				let categories = try await pendingCategories
				self.refreshProgress.completeTask()

				let feeds = try await pendingFeeds
				self.refreshProgress.completeTask()

				BatchUpdate.shared.perform {
					self.syncFolders(account, categories)
					self.syncFeeds(account, feeds)
					self.syncFeedFolderRelationship(account, feeds)
				}
				self.refreshProgress.completeTask()
				return (folders: categories.count, feeds: feeds.count)
			})
		} catch {
			account.postSyncError(error, operation: "Refreshing account")
			throw error
		}
	}

	func refreshArticlesAndStatuses(_ account: Account) async throws {
		let isInitialSync = accountSettings?.lastRefreshCompletedDate == nil

		// A failed status send must not block fetching new articles.
		// <https://discourse.netnewswire.com/t/no-feed-updates/336>
		try? await sendArticleStatus()
		_ = try await refreshArticles(account, reportProgress: true)

		if isInitialSync {
			// The published_after window misses older unread and starred entries. Reconcile first, so refreshMissingArticles downloads them.
			_ = try await reconcileAllArticleStatuses(for: account)
		}

		try await refreshMissingArticles(account)
		accountSettings?.lastRefreshCompletedDate = Date()
		refreshProgress.reset()
	}

	/// Folders match categories by externalID, not name, so renaming a category keeps its folder.
	func syncFolders(_ account: Account, _ categories: [MinifluxCategory]) {
		assert(Thread.isMainThread)

		Self.logger.info("Miniflux: Syncing folders with \(categories.count) categories")

		let categoryExternalIDs = Set(categories.map { String($0.categoryID) })

		// Delete any folders whose category is gone.
		if let folders = account.folders {
			for folder in folders {
				if !categoryExternalIDs.contains(folder.externalID ?? "") {
					account.removeFolderFromTree(folder)
				}
			}
		}

		let folderDict = externalIDToFolderDictionary(with: account.folders)

		for category in categories {
			let externalID = String(category.categoryID)
			if let folder = folderDict[externalID] {
				if folder.name != category.title {
					folder.name = category.title
				}
			} else {
				// Every remaining folder belongs to a live category, so matching by name would take another category’s folder.
				let folder = Folder(account: account, name: category.title)
				folder.externalID = externalID
				account.addFolderToTree(folder)
			}
		}
	}

	func syncFeeds(_ account: Account, _ feeds: [MinifluxFeed]) {
		assert(Thread.isMainThread)

		Self.logger.info("Miniflux: Syncing feeds with \(feeds.count) feeds")

		let feedExternalIDs = Set(feeds.map { String($0.feedID) })

		// Remove any feeds that are no longer on the server.
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !feedExternalIDs.contains(feed.feedID) {
						// Clear settings first, so a feed re-added at this URL, which gets a new feedID, doesn’t inherit the old one.
						account.clearFeedSettings(feed)
						folder.removeFeedFromTreeAtTopLevel(feed)
					}
				}
			}
		}

		// Miniflux has no top level, so a top-level feed is either gone or belongs in its category’s folder.
		let categorizedFeedExternalIDs = Set(feeds.filter { $0.category != nil }.map { String($0.feedID) })
		for feed in account.topLevelFeeds {
			if !feedExternalIDs.contains(feed.feedID) {
				account.clearFeedSettings(feed)
				account.removeFeedFromTreeAtTopLevel(feed)
			} else if categorizedFeedExternalIDs.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		// Update existing feeds. syncFeedFolderRelationship adds new ones to their folders.
		for feed in feeds {
			let feedExternalID = String(feed.feedID)
			if let existingFeed = account.existingFeed(withFeedID: feedExternalID) {
				existingFeed.name = feed.title
				existingFeed.editedName = nil
				existingFeed.homePageURL = feed.siteURL
			}
		}
	}

	/// A feed’s folder comes from its category on every refresh, so there’s no `folderRelationship` bookkeeping.
	func syncFeedFolderRelationship(_ account: Account, _ feeds: [MinifluxFeed]) {
		assert(Thread.isMainThread)

		Self.logger.info("Miniflux: Syncing feed folder relationships")

		let folderDict = externalIDToFolderDictionary(with: account.folders)
		let feedsByCategoryID = feeds.reduce(into: [String: [MinifluxFeed]]()) { dict, feed in
			guard let categoryID = feed.category?.categoryID else {
				return
			}
			dict[String(categoryID), default: []].append(feed)
		}

		// A feed with no category (a lenient decode) stays in its current folder.
		var feedIDsWithNoCategory = Set<String>()
		for feed in feeds where feed.category == nil {
			feedIDsWithNoCategory.insert(String(feed.feedID))
			Self.logger.error("Miniflux: Feed \(feed.feedID) has no category, so its local folder placement is unchanged")
		}

		for (categoryExternalID, folder) in folderDict {
			let categoryFeeds = feedsByCategoryID[categoryExternalID] ?? []
			let categoryFeedExternalIDs = Set(categoryFeeds.map { String($0.feedID) })

			// Remove any feeds no longer in this category.
			for feed in folder.topLevelFeeds {
				if feedIDsWithNoCategory.contains(feed.feedID) {
					continue
				}
				if !categoryFeedExternalIDs.contains(feed.feedID) {
					folder.removeFeedFromTreeAtTopLevel(feed)
				}
			}

			// Add any feeds not yet in this folder.
			let folderFeedExternalIDs = Set(folder.topLevelFeeds.map { $0.feedID })
			for feed in categoryFeeds {
				let feedExternalID = String(feed.feedID)
				guard !folderFeedExternalIDs.contains(feedExternalID) else {
					continue
				}
				if let existingFeed = account.existingFeed(withFeedID: feedExternalID) {
					folder.addFeedToTreeAtTopLevel(existingFeed)
				} else {
					let newFeed = account.createFeed(with: feed.title, url: feed.feedURL, feedID: feedExternalID, homePageURL: feed.siteURL)
					newFeed.externalID = feedExternalID
					folder.addFeedToTreeAtTopLevel(newFeed)
				}
			}
		}
	}

	func externalIDToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders else {
			return [:]
		}

		let pairs = folders.compactMap { folder -> (String, Folder)? in
			guard let externalID = folder.externalID else {
				return nil
			}
			return (externalID, folder)
		}
		return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
	}

	/// Returns the number of local statuses changed.
	@discardableResult
	func refreshArticles(_ account: Account, reportProgress: Bool = false) async throws -> Int {
		Self.logger.info("Miniflux: Refreshing articles")

		do {
			let fetchStartDate = Date()
			let changedAfter = accountSettings?.lastArticleFetchStartTime?.addingTimeInterval(-Self.changedAfterClockSkewMargin)
			// With no changed_after, as on the first sync or after an OPML import, limit the fetch to recent history.
			let publishedAfter = changedAfter == nil ? Calendar.current.date(byAdding: .month, value: -Self.articleHistoryMonths, to: fetchStartDate) : nil

			let counts = try await account.logActivity(kind: .refreshArticles, successMessage: { "\($0.entryCount) articles" }, {
				try await refreshArticlePages(account: account, changedAfter: changedAfter, publishedAfter: publishedAfter, reportProgress: reportProgress)
			})

			accountSettings?.lastArticleFetchStartTime = fetchStartDate
			return counts.changedStatusCount
		} catch {
			account.postSyncError(error, operation: "Refreshing articles")
			throw error
		}
	}

	/// With `reportProgress`, the caller adds the first page’s progress task, and later pages add their own.
	func refreshArticlePages(account: Account, changedAfter: Date?, publishedAfter: Date?, reportProgress: Bool) async throws -> (entryCount: Int, changedStatusCount: Int) {
		var offset = 0
		var totalEntriesProcessed = 0
		var changedStatusCount = 0
		var isFirstPage = true

		while true {
			if reportProgress && !isFirstPage {
				refreshProgress.addTask()
			}
			isFirstPage = false
			// Complete the task on every exit, including a thrown error.
			defer {
				if reportProgress {
					refreshProgress.completeTask()
				}
			}

			let pageOffset = offset
			let response = try await account.logRefreshPage(kind: .refreshArticles, message: { "\($0.entries.count) articles" }, {
				try await caller.retrieveEntries(offset: pageOffset, changedAfter: changedAfter, publishedAfter: publishedAfter)
			})

			totalEntriesProcessed += response.entries.count
			changedStatusCount += await processEntries(account: account, entries: response.entries)

			offset += response.entries.count
			if response.entries.isEmpty || offset >= response.total {
				break
			}
		}

		return (totalEntriesProcessed, changedStatusCount)
	}

	func refreshMissingArticles(_ account: Account) async throws {
		Self.logger.info("Miniflux: Refreshing missing articles")
		defer {
			refreshProgress.completeTask()
			Self.logger.info("Miniflux: Finished refreshing missing articles")
		}

		try await account.logActivity(kind: .refreshMissingArticles) {
			var savedError: Error?

			let fetchedArticleIDs = await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
			// Newest first, since Miniflux fetches one entry per request.
			let entryIDs = fetchedArticleIDs.compactMap { Int($0) }.sorted(by: >).prefix(Self.missingArticlesFetchLimit)

			for chunk in Array(entryIDs).chunked(into: Self.missingArticlesChunkSize) {
				let result: (entries: [MinifluxEntry], serverDeletedArticleIDs: Set<String>)
				do {
					result = try await account.logRefreshPage(kind: .refreshMissingArticles, message: { "\($0.entries.count) articles" }, {
						try await retrieveMissingEntries(entryIDs: chunk)
					})
				} catch {
					savedError = error
					break
				}

				await processEntries(account: account, entries: result.entries)

				// A 404 means the entry is gone on the server, so its status would be re-requested forever.
				if !result.serverDeletedArticleIDs.isEmpty {
					Self.logger.info("Miniflux: Deleting statuses for \(result.serverDeletedArticleIDs.count) entries removed on the server")
					await account.deleteStatuses(articleIDs: result.serverDeletedArticleIDs)
				}
			}

			if let savedError {
				account.postSyncError(savedError, operation: "Refreshing missing articles")
				throw savedError
			}
		}
	}

	/// Fetches each entry, one request per entry. Returns the entries found and the IDs of entries deleted on the server.
	func retrieveMissingEntries(entryIDs: [Int]) async throws -> (entries: [MinifluxEntry], serverDeletedArticleIDs: Set<String>) {
		var entries = [MinifluxEntry]()
		var serverDeletedArticleIDs = Set<String>()

		for entryID in entryIDs {
			do {
				if let entry = try await caller.retrieveEntry(entryID: entryID) {
					entries.append(entry)
				} else {
					serverDeletedArticleIDs.insert(String(entryID))
				}
			} catch {
				Self.logger.error("Miniflux: Refresh missing articles error: \(error.localizedDescription)")
				// An HTTP error is about this entry, so skip it without failing the refresh. Anything else, such as no connection, would fail every remaining request.
				if case WebserviceError.httpError = error {
					continue
				}
				throw error
			}
		}

		return (entries, serverDeletedArticleIDs)
	}

	/// Returns the number of local statuses changed.
	@discardableResult
	func processEntries(account: Account, entries: [MinifluxEntry]) async -> Int {
		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }
		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
		return await applyEntryStatuses(account: account, entries: entries)
	}

	/// Applies statuses from the changed_after entries fetch, except pending local changes, which win. Returns the number of statuses changed.
	@discardableResult
	func applyEntryStatuses(account: Account, entries: [MinifluxEntry]) async -> Int {
		guard !entries.isEmpty else {
			return 0
		}

		let pendingReadArticleIDs = try? await syncDatabase.selectPendingReadStatusArticleIDs()
		let pendingStarredArticleIDs = try? await syncDatabase.selectPendingStarredStatusArticleIDs()

		if pendingReadArticleIDs == nil {
			Self.logger.error("Miniflux: Sync database selectPendingReadStatusArticleIDs failed, so read statuses won’t be applied")
		}
		if pendingStarredArticleIDs == nil {
			Self.logger.error("Miniflux: Sync database selectPendingStarredStatusArticleIDs failed, so starred statuses won’t be applied")
		}

		var unreadIDs = Set<String>()
		var readIDs = Set<String>()
		var starredIDs = Set<String>()
		var unstarredIDs = Set<String>()

		for entry in entries {
			let articleID = String(entry.entryID)
			if entry.status == .unread {
				unreadIDs.insert(articleID)
			} else if entry.status == .read {
				readIDs.insert(articleID)
			}
			if entry.starred == true {
				starredIDs.insert(articleID)
			} else if entry.starred == false {
				unstarredIDs.insert(articleID)
			}
		}

		var changedCount = 0
		if let pendingReadArticleIDs {
			changedCount += await account.updateStatusesAsync(articleIDs: unreadIDs.subtracting(pendingReadArticleIDs), statusKey: .read, flag: false).count
			changedCount += await account.updateStatusesAsync(articleIDs: readIDs.subtracting(pendingReadArticleIDs), statusKey: .read, flag: true).count
		}
		if let pendingStarredArticleIDs {
			changedCount += await account.updateStatusesAsync(articleIDs: starredIDs.subtracting(pendingStarredArticleIDs), statusKey: .starred, flag: true).count
			changedCount += await account.updateStatusesAsync(articleIDs: unstarredIDs.subtracting(pendingStarredArticleIDs), statusKey: .starred, flag: false).count
		}
		return changedCount
	}

	func mapEntriesToParsedItems(entries: [MinifluxEntry]) -> Set<ParsedItem> {
		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = entry.author.map { Set([ParsedAuthor(name: $0, url: nil, avatarURL: nil, emailAddress: nil)]) }
			return ParsedItem(syncServiceID: String(entry.entryID), uniqueID: String(entry.entryID), feedURL: String(entry.feedID), url: entry.url, externalURL: nil, title: entry.title, language: nil, contentHTML: entry.contentHTML, contentText: nil, markdown: nil, summary: nil, imageURL: entry.imageURL, thumbnailURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: entry.attachments)
		}

		return Set(parsedItems)
	}

	func syncArticleReadState(account: Account, entryIDs: Set<Int>) async -> Int {
		guard let pendingArticleIDs = try? await syncDatabase.selectPendingReadStatusArticleIDs() else {
			Self.logger.error("Miniflux: Sync database selectPendingReadStatusArticleIDs failed")
			return 0
		}

		return await syncArticleState(
			entryIDs: entryIDs,
			pendingArticleIDs: pendingArticleIDs,
			currentArticleIDs: { await account.fetchUnreadArticleIDsAsync() },
			markOn: { await account.markAsUnreadAsync(articleIDs: $0) },
			markOff: { await account.markAsReadAsync(articleIDs: $0) }
		)
	}

	func syncArticleStarredState(account: Account, entryIDs: Set<Int>) async -> Int {
		guard let pendingArticleIDs = try? await syncDatabase.selectPendingStarredStatusArticleIDs() else {
			Self.logger.error("Miniflux: Sync database selectPendingStarredStatusArticleIDs failed")
			return 0
		}

		return await syncArticleState(
			entryIDs: entryIDs,
			pendingArticleIDs: pendingArticleIDs,
			currentArticleIDs: { await account.fetchStarredArticleIDsAsync() },
			markOn: { await account.markAsStarredAsync(articleIDs: $0) },
			markOff: { await account.markAsUnstarredAsync(articleIDs: $0) }
		)
	}

	/// Sends `entryIDs` in chunks, deleting their sync rows on success and resetting them on failure. Returns the count sent.
	func sendEntryStatuses(_ entryIDs: [Int], key: SyncStatus.Key, update: (_ chunk: [Int]) async throws -> Void) async throws -> Int {
		guard !entryIDs.isEmpty else {
			return 0
		}

		var savedError: Error?
		var sentCount = 0

		for chunk in entryIDs.chunked(into: MinifluxAPICaller.statusChunkSize) {
			let articleIDs = Set(chunk.map { String($0) })
			do {
				try await update(chunk)
				await syncDatabase.deleteSelectedForProcessing(articleIDs, key: key)
				sentCount += chunk.count
			} catch {
				savedError = error
				Self.logger.error("Miniflux: Status sync call failed: \(error.localizedDescription)")
				await syncDatabase.resetSelectedForProcessing(articleIDs, key: key)
			}
		}

		if let savedError {
			throw savedError
		}
		return sentCount
	}

	/// Numeric entry IDs of the pending sync statuses matching `key`/`flag`.
	func pendingEntryIDs(in statuses: some Sequence<SyncStatus>, key: SyncStatus.Key, flag: Bool) -> [Int] {
		statuses.filter { $0.key == key && $0.flag == flag }.compactMap { Int($0.articleID) }
	}

	/// The folder’s category, or the lowest-id category when `container` is the account, since every Miniflux feed needs one.
	func categoryID(for container: Container) async throws -> Int {
		if let folder = container as? Folder, let externalID = folder.externalID, let categoryID = Int(externalID) {
			return categoryID
		}

		let categories = try await caller.retrieveCategories()
		guard let lowestCategory = categories.min(by: { $0.categoryID < $1.categoryID }) else {
			throw AccountError.invalidParameter
		}
		return lowestCategory.categoryID
	}

	@discardableResult
	func createFeed(account: Account, feedID: Int, name: String?, categoryID: Int) async throws -> Feed {
		let minifluxFeed = try await caller.retrieveFeed(feedID: feedID)

		let feed = account.createFeed(with: minifluxFeed.title, url: minifluxFeed.feedURL, feedID: String(feedID), homePageURL: minifluxFeed.siteURL)
		feed.externalID = String(feedID)

		// The feed is already in this category on the server, so add it locally without another move.
		if let folder = account.existingFolder(withExternalID: String(categoryID)) {
			folder.addFeedToTreeAtTopLevel(feed)
		} else {
			account.addFeedToTreeAtTopLevel(feed)
		}
		if let name {
			try await renameFeed(with: feed, to: name)
		}

		Task {
			do {
				try await initialFeedDownload(account: account, feed: feed, feedID: feedID)
			} catch {
				Self.logger.error("Miniflux: Initial feed download failed: \(error.localizedDescription)")
				account.postSyncError(error, operation: "Downloading feed articles")
			}
		}

		return feed
	}

	func initialFeedDownload(account: Account, feed: Feed, feedID: Int) async throws {
		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		try await account.logActivity(kind: .refreshFeedContent(feedURL: feed.url), detail: feed.nameForDisplay) {
			var offset = 0
			while true {
				let response = try await caller.retrieveEntries(feedID: feedID, offset: offset)
				await processEntries(account: account, entries: response.entries)

				offset += response.entries.count
				if offset >= response.total || response.entries.isEmpty {
					break
				}
			}
		}
	}
}

extension MinifluxAccountDelegate {
	func syncArticleState(entryIDs: Set<Int>, pendingArticleIDs: Set<String>, currentArticleIDs: () async -> Set<String>, markOn: (Set<String>) async -> Set<String>, markOff: (Set<String>) async -> Set<String>) async -> Int {
		let serverArticleIDs = Set(entryIDs.map { String($0) })
		let updatableArticleIDs = serverArticleIDs.subtracting(pendingArticleIDs)

		let currentIDs = await currentArticleIDs()
		let deltaOnArticleIDs = updatableArticleIDs.subtracting(currentIDs)
		let markedOn = await markOn(deltaOnArticleIDs)

		let deltaOffArticleIDs = currentIDs.subtracting(updatableArticleIDs).subtracting(pendingArticleIDs)
		let markedOff = await markOff(deltaOffArticleIDs)

		return markedOn.count + markedOff.count
	}
}
