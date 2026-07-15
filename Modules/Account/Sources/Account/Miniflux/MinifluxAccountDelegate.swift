//
//  MinifluxAccountDelegate.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ActivityLog
import Articles
import ErrorLog
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
	private static let logger = Miniflux.logger
	/// Send statuses immediately once this many are queued, rather than waiting for the next scheduled sync.
	private static let sendStatusBatchThreshold = 100

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
		// Five tasks completed across refreshAccount and refreshArticlesAndStatuses:
		// categories fetch, feeds fetch, local folder/feed sync, the first page of
		// articles, and missing articles. Continuation article pages add their own
		// tasks as they're fetched.
		refreshProgress.addTasks(5)

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
		let refreshedCount = try await refreshArticles(account)
		return sentCount > 0 || refreshedCount > 0
	}

	func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await sendArticleStatusReturningCount(for: account)
	}

	/// Sends queued local status changes upstream. Returns the count successfully sent.
	private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.info("Miniflux: Sending article statuses")
		defer {
			Self.logger.info("Miniflux: Finished sending article statuses")
		}

		do {
			return try await account.logActivity(kind: .sendArticleStatuses) { () -> Int in
				guard let syncStatuses = await syncDatabase.selectForProcessing() else {
					Self.logger.error("Miniflux: Sync database selectForProcessing failed")
					return 0
				}

				var sentCount = 0

				sentCount += try await sendEntryStatuses(pendingEntryIDs(in: syncStatuses, key: .read, flag: true)) {
					try await caller.updateEntries(entryIDs: $0, read: true)
				}
				sentCount += try await sendEntryStatuses(pendingEntryIDs(in: syncStatuses, key: .read, flag: false)) {
					try await caller.updateEntries(entryIDs: $0, read: false)
				}
				sentCount += try await sendEntryStatuses(pendingEntryIDs(in: syncStatuses, key: .starred, flag: true)) {
					try await caller.updateEntries(entryIDs: $0, starred: true)
				}
				sentCount += try await sendEntryStatuses(pendingEntryIDs(in: syncStatuses, key: .starred, flag: false)) {
					try await caller.updateEntries(entryIDs: $0, starred: false)
				}

				return sentCount
			}
		} catch {
			postSyncError(error, account: account, operation: "Sending article status")
			throw error
		}
	}

	/// Status changes arrive via the changed_after entries fetch (statuses ride along
	/// with content), so refreshing statuses is the same operation as refreshing articles.
	func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await refreshArticles(account)
	}

	/// Full reconciliation against the server's complete unread/starred ID sets. Used only
	/// on initial sync now — routine refreshes get status changes from the changed_after
	/// entries fetch. Returns the count of articles whose local state actually changed.
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
				postSyncError(refreshError, account: account, operation: "Refreshing article status")
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
			Self.logger.info("Miniflux: OPML import failed: \(error.localizedDescription)")
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
		defer { refreshProgress.completeTask() }

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
		guard let externalID = folder.externalID, let categoryID = Int64(externalID) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

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
		guard let externalID = folder.externalID, let categoryID = Int64(externalID) else {
			throw AccountError.invalidParameter
		}

		try await account.logActivity(kind: .removeFolder, detail: folder.name) {
			refreshProgress.addTasks(folder.topLevelFeeds.count)

			for feed in folder.topLevelFeeds {
				defer { refreshProgress.completeTask() }

				guard let feedExternalID = feed.externalID, let feedID = Int64(feedExternalID) else {
					continue
				}
				do {
					try await caller.deleteFeed(feedID: feedID)
					account.clearFeedSettings(feed)
				} catch {
					Self.logger.error("Miniflux: Remove feed error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Removing feed")
				}
			}

			// Miniflux refuses to delete a category that still has feeds — throw rather than
			// silently leaving the folder gone locally but present on the server.
			try await caller.deleteCategory(categoryID: categoryID)
			account.removeFolderFromTree(folder)
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

		refreshProgress.addTasks(2)
		var uncompletedTasks = 2
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

				return try await createFeed(account: account, feedID: feedID, name: name, container: container)
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		guard let externalID = feed.externalID, let feedID = Int64(externalID) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

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
		guard let externalID = feed.externalID, let feedID = Int64(externalID) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

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
			let feedID = Int64(feedExternalID),
			let destinationExternalID = (destinationContainer as? Folder)?.externalID,
			let destinationCategoryID = Int64(destinationExternalID)
		else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

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
					let feedID = Int64(feedExternalID),
					let folderExternalID = folder.externalID,
					let destinationCategoryID = Int64(folderExternalID)
				else {
					throw AccountError.invalidParameter
				}

				refreshProgress.addTask()
				defer { refreshProgress.completeTask() }

				do {
					try await caller.moveFeed(feedID: feedID, categoryID: destinationCategoryID)
					account.removeFeedFromTreeAtTopLevel(feed)
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
		await account.logActivity(kind: .restoreFolder, detail: folder.name ?? "") {
			// The category was deleted server-side along with the folder — re-create it and
			// point the folder at the new externalID before restoring its member feeds.
			do {
				let category = try await caller.createCategory(title: folder.name ?? "")
				folder.externalID = String(category.categoryID)
			} catch {
				Self.logger.error("Miniflux: Restore folder category error: \(error.localizedDescription)")
				postSyncError(error, account: account, operation: "Restoring folder")
				return
			}

			for feed in folder.topLevelFeeds {
				folder.topLevelFeeds.remove(feed)

				do {
					try await restoreFeed(feed: feed, container: folder)
				} catch {
					Self.logger.error("Miniflux: Restore folder feed error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Restoring feed")
				}
			}

			account.addFolderToTree(folder)
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
		if let count = await syncDatabase.selectPendingCount(), count > Self.sendStatusBatchThreshold {
			try await sendArticleStatus()
		}
	}

	func accountDidInitialize() {
		guard let account else {
			return
		}
		retrieveCredentialsIfNeeded(account)
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
			postSyncError(error, account: account, operation: "Refreshing account")
			throw error
		}
	}

	func refreshArticlesAndStatuses(_ account: Account) async throws {
		// Captured before refreshArticles advances lastArticleFetchStartTime.
		let isInitialSync = accountSettings?.lastArticleFetchStartTime == nil

		try await sendArticleStatus()
		_ = try await refreshArticles(account, reportProgress: true)

		if isInitialSync {
			// The first sync's published_after window misses older unread/starred entries;
			// a one-time full ID reconciliation (plus refreshMissingArticles right after)
			// pulls them in. Order matters: reconcile must run before refreshMissingArticles
			// so the statuses it creates get their articles downloaded.
			_ = try await reconcileAllArticleStatuses(for: account)
		}

		try await refreshMissingArticles(account)
		accountSettings?.lastRefreshCompletedDate = Date()
		refreshProgress.reset()
	}

	/// Every Miniflux category maps to exactly one NNW folder, matched by externalID
	/// (the category's server-side id), not by name — so a category rename doesn't
	/// orphan the folder.
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
				let folder = account.ensureFolder(with: category.title)
				folder?.externalID = externalID
			}
		}
	}

	func syncFeeds(_ account: Account, _ feeds: [MinifluxFeed]) {
		assert(Thread.isMainThread)

		Self.logger.info("Miniflux: Syncing feeds with \(feeds.count) feeds")

		let feedExternalIDs = Set(feeds.map { String($0.feedID) })

		// Remove any feeds that are no longer on the server. Miniflux guarantees every
		// feed has a category, so feeds only ever live inside folders — never at the
		// account top level.
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !feedExternalIDs.contains(feed.feedID) {
						// Clear settings before removing so a feed re-added at this URL — which
						// Miniflux assigns a new numeric feedID — doesn't inherit the stale
						// feedID from the settings cache/database and end up unable to match
						// incoming articles.
						account.clearFeedSettings(feed)
						folder.removeFeedFromTreeAtTopLevel(feed)
					}
				}
			}
		}

		// Add any feeds we don't have and update any we do. New feeds are added directly
		// to their folder in syncFeedFolderRelationship — Miniflux guarantees every feed
		// has exactly one category.
		for feed in feeds {
			let feedExternalID = String(feed.feedID)
			if let existingFeed = account.existingFeed(withFeedID: feedExternalID) {
				existingFeed.name = feed.title
				existingFeed.editedName = nil
				existingFeed.homePageURL = feed.siteURL
				existingFeed.externalID = feedExternalID
			}
		}
	}

	/// No `folderRelationship` bookkeeping — a feed's folder membership is derived
	/// entirely from its `category.id` on each refresh.
	func syncFeedFolderRelationship(_ account: Account, _ feeds: [MinifluxFeed]) {
		assert(Thread.isMainThread)

		Self.logger.info("Miniflux: Syncing feed folder relationships")

		let folderDict = externalIDToFolderDictionary(with: account.folders)
		let feedsByCategoryID = feeds.reduce(into: [String: [MinifluxFeed]]()) { dict, feed in
			guard let categoryID = feed.category?.categoryID else { return }
			dict[String(categoryID), default: []].append(feed)
		}

		// Feeds with no category (a lenient decode) must not be silently pulled out of
		// their existing folder — track them so the removal loop below leaves them alone.
		var feedIDsWithNoCategory = Set<String>()
		for feed in feeds where feed.category == nil {
			feedIDsWithNoCategory.insert(String(feed.feedID))
			Self.logger.error("Miniflux: Feed \(feed.feedID) has no category; leaving local folder placement unchanged")
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

	@discardableResult
	func refreshArticles(_ account: Account, reportProgress: Bool = false) async throws -> Int {
		Self.logger.info("Miniflux: Refreshing articles")

		do {
			let fetchStartDate = Date()
			let isInitialSync = accountSettings?.lastArticleFetchStartTime == nil
			let changedAfter = isInitialSync ? nil : accountSettings?.lastArticleFetchStartTime
			let publishedAfter = isInitialSync ? Calendar.current.date(byAdding: .month, value: -3, to: fetchStartDate) : nil

			let processedCount = try await account.logActivity(kind: .refreshArticles, successMessage: { "\($0) articles" }, {
				try await refreshArticlesPage(account: account, changedAfter: changedAfter, publishedAfter: publishedAfter, reportProgress: reportProgress)
			})

			accountSettings?.lastArticleFetchStartTime = fetchStartDate
			return processedCount
		} catch {
			postSyncError(error, account: account, operation: "Refreshing articles")
			throw error
		}
	}

	/// When `reportProgress` is true, the caller must have pre-added one task for the
	/// first page (keeping the progress denominator stable for single-page refreshes);
	/// continuation pages add their own. Background status syncs pass false so the
	/// progress UI stays quiet.
	func refreshArticlesPage(account: Account, changedAfter: Date?, publishedAfter: Date?, reportProgress: Bool) async throws -> Int {
		var offset = 0
		var totalEntriesProcessed = 0
		var isFirstPage = true

		while true {
			if reportProgress && !isFirstPage {
				refreshProgress.addTask()
			}
			isFirstPage = false
			// Complete the task on every exit from this iteration — including a thrown
			// fetch error — so a task is never stranded.
			defer {
				if reportProgress {
					refreshProgress.completeTask()
				}
			}

			let pageOffset = offset
			let response = try await account.logActivity(kind: .refreshArticles, detail: ActivityLog.shared.nextTaskNumberString(), successMessage: { "\($0.entries.count) articles" }, {
				try await caller.retrieveEntries(offset: pageOffset, changedAfter: changedAfter, publishedAfter: publishedAfter)
			})

			totalEntriesProcessed += response.entries.count
			await processEntries(account: account, entries: response.entries)

			offset += response.entries.count
			if response.entries.isEmpty || offset >= response.total {
				break
			}
		}

		return totalEntriesProcessed
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
			let entryIDs = fetchedArticleIDs.compactMap { Int64($0) }
			let chunkedEntryIDs = entryIDs.chunked(into: 100)
			var serverDeletedArticleIDs = Set<String>()

			for chunk in chunkedEntryIDs {
				do {
					var entries = [MinifluxEntry]()
					for entryID in chunk {
						if let entry = try await caller.retrieveEntry(entryID: entryID) {
							entries.append(entry)
						} else {
							serverDeletedArticleIDs.insert(String(entryID))
						}
					}
					await processEntries(account: account, entries: entries)
				} catch {
					savedError = error
					Self.logger.error("Miniflux: Refresh missing articles error: \(error.localizedDescription)")
				}
			}

			// A 404 from retrieveEntry means the entry is gone server-side (feed deleted,
			// server cleanup). Delete those statuses — otherwise they match the
			// statuses-without-articles query again on every refresh, and we re-request
			// articles the server will never return.
			if !serverDeletedArticleIDs.isEmpty {
				Self.logger.info("Miniflux: Deleting statuses for \(serverDeletedArticleIDs.count) entries removed on the server")
				await account.deleteStatuses(articleIDs: serverDeletedArticleIDs)
			}

			if let savedError {
				postSyncError(savedError, account: account, operation: "Refreshing missing articles")
				throw savedError
			}
		}
	}

	func processEntries(account: Account, entries: [MinifluxEntry]) async {
		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }
		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
		await applyEntryStatuses(account: account, entries: entries)
	}

	/// Statuses ride along on the changed_after entries fetch — Miniflux bumps changed_at
	/// whenever an entry's status or starred state changes — so applying them per page
	/// replaces the per-refresh full ID scans. Pending local changes are always excluded:
	/// they must win, so server state is never applied without first knowing what's pending.
	func applyEntryStatuses(account: Account, entries: [MinifluxEntry]) async {
		guard !entries.isEmpty else {
			return
		}

		let pendingReadArticleIDs = await syncDatabase.selectPendingReadStatusArticleIDs()
		let pendingStarredArticleIDs = await syncDatabase.selectPendingStarredStatusArticleIDs()

		if pendingReadArticleIDs == nil {
			Self.logger.error("Miniflux: Sync database selectPendingReadStatusArticleIDs failed; skipping read status application")
		}
		if pendingStarredArticleIDs == nil {
			Self.logger.error("Miniflux: Sync database selectPendingStarredStatusArticleIDs failed; skipping starred status application")
		}

		var unreadIDs = Set<String>()
		var readIDs = Set<String>()
		var starredIDs = Set<String>()
		var unstarredIDs = Set<String>()

		for entry in entries {
			let articleID = String(entry.entryID)
			if entry.status == "unread" {
				unreadIDs.insert(articleID)
			} else if entry.status == "read" {
				readIDs.insert(articleID)
			}
			if entry.starred == true {
				starredIDs.insert(articleID)
			} else if entry.starred == false {
				unstarredIDs.insert(articleID)
			}
		}

		if let pendingReadArticleIDs {
			_ = await account.markAsUnreadAsync(articleIDs: unreadIDs.subtracting(pendingReadArticleIDs))
			_ = await account.markAsReadAsync(articleIDs: readIDs.subtracting(pendingReadArticleIDs))
		}
		if let pendingStarredArticleIDs {
			_ = await account.markAsStarredAsync(articleIDs: starredIDs.subtracting(pendingStarredArticleIDs))
			_ = await account.markAsUnstarredAsync(articleIDs: unstarredIDs.subtracting(pendingStarredArticleIDs))
		}
	}

	func mapEntriesToParsedItems(entries: [MinifluxEntry]) -> Set<ParsedItem> {
		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = entry.author.map { Set([ParsedAuthor(name: $0, url: nil, avatarURL: nil, emailAddress: nil)]) }

			let attachments: Set<ParsedAttachment>? = {
				guard let enclosures = entry.enclosures else {
					return nil
				}
				let parsedAttachments = enclosures.compactMap { enclosure -> ParsedAttachment? in
					guard let url = enclosure.url else {
						return nil
					}
					return ParsedAttachment(url: url, mimeType: enclosure.mimeType, title: nil, sizeInBytes: nil, durationInSeconds: nil)
				}
				return parsedAttachments.isEmpty ? nil : Set(parsedAttachments)
			}()

			return ParsedItem(syncServiceID: String(entry.entryID), uniqueID: String(entry.entryID), feedURL: String(entry.feedID), url: entry.url, externalURL: nil, title: entry.title, language: nil, contentHTML: entry.contentHTML, contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: attachments)
		}

		return Set(parsedItems)
	}

	func syncArticleReadState(account: Account, entryIDs: Set<Int64>) async -> Int {
		guard let pendingArticleIDs = await syncDatabase.selectPendingReadStatusArticleIDs() else {
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

	func syncArticleStarredState(account: Account, entryIDs: Set<Int64>) async -> Int {
		guard let pendingArticleIDs = await syncDatabase.selectPendingStarredStatusArticleIDs() else {
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

	/// Shared core for `syncArticleReadState`/`syncArticleStarredState`: reconciles the server's
	/// set of entry IDs (unread or starred, depending on caller) against local state, skipping
	/// any article IDs still pending an outgoing status change.
	func syncArticleState(entryIDs: Set<Int64>, pendingArticleIDs: Set<String>, currentArticleIDs: () async -> Set<String>, markOn: (Set<String>) async -> Set<String>, markOff: (Set<String>) async -> Set<String>) async -> Int {
		let serverArticleIDs = Set(entryIDs.map { String($0) })
		let updatableArticleIDs = serverArticleIDs.subtracting(pendingArticleIDs)

		let currentIDs = await currentArticleIDs()

		// Mark articles matching the server's state (e.g. unread, or starred).
		let deltaOnArticleIDs = updatableArticleIDs.subtracting(currentIDs)
		let markedOn = await markOn(deltaOnArticleIDs)

		// Mark articles no longer matching the server's state (e.g. read, or unstarred).
		let deltaOffArticleIDs = currentIDs.subtracting(updatableArticleIDs)
		let markedOff = await markOff(deltaOffArticleIDs)

		return markedOn.count + markedOff.count
	}

	/// Read/unread and starred/unstarred changes all funnel through here. Chunks `entryIDs`,
	/// pushes each chunk via `update`, then clears the sync-database rows on success or resets
	/// them on failure. Miniflux’s update-entries call is absolute state (not a toggle), so
	/// repeated sends are idempotent. Returns the count successfully sent.
	func sendEntryStatuses(_ entryIDs: [Int64], update: (_ chunk: [Int64]) async throws -> Void) async throws -> Int {
		guard !entryIDs.isEmpty else {
			return 0
		}

		var savedError: Error?
		var sentCount = 0

		for chunk in entryIDs.chunked(into: MinifluxAPICaller.statusChunkSize) {
			let articleIDs = Set(chunk.map { String($0) })
			do {
				try await update(chunk)
				await syncDatabase.deleteSelectedForProcessing(articleIDs)
				sentCount += chunk.count
			} catch {
				savedError = error
				Self.logger.error("Miniflux: Status sync call failed: \(error.localizedDescription)")
				await syncDatabase.resetSelectedForProcessing(articleIDs)
			}
		}

		if let savedError {
			throw savedError
		}
		return sentCount
	}

	/// Numeric entry IDs of the pending sync statuses matching `key`/`flag`.
	func pendingEntryIDs(in statuses: some Sequence<SyncStatus>, key: SyncStatus.Key, flag: Bool) -> [Int64] {
		statuses.filter { $0.key == key && $0.flag == flag }.compactMap { Int64($0.articleID) }
	}

	/// Resolves the category to use when creating a feed into `container`: the folder's
	/// externalID if `container` is a Folder, otherwise the lowest-id category (used when
	/// the UI hands us the account itself as the container, which Miniflux has no concept
	/// of — every feed must belong to a category).
	func categoryID(for container: Container) async throws -> Int64 {
		if let folder = container as? Folder, let externalID = folder.externalID, let categoryID = Int64(externalID) {
			return categoryID
		}

		let categories = try await caller.retrieveCategories()
		guard let lowestCategory = categories.min(by: { $0.categoryID < $1.categoryID }) else {
			throw AccountError.invalidParameter
		}
		return lowestCategory.categoryID
	}

	@discardableResult
	func createFeed(account: Account, feedID: Int64, name: String?, container: Container) async throws -> Feed {
		let minifluxFeed = try await caller.retrieveFeed(feedID: feedID)

		let feed = account.createFeed(with: minifluxFeed.title, url: minifluxFeed.feedURL, feedID: String(feedID), homePageURL: minifluxFeed.siteURL)
		feed.externalID = String(feedID)

		try await account.addFeed(feed, container: container)
		if let name {
			try await renameFeed(with: feed, to: name)
		}

		Task {
			do {
				try await initialFeedDownload(account: account, feed: feed, feedID: feedID)
			} catch {
				Self.logger.error("Miniflux: Initial feed download failed: \(error.localizedDescription)")
				postSyncError(error, account: account, operation: "Downloading feed articles")
			}
		}

		return feed
	}

	func initialFeedDownload(account: Account, feed: Feed, feedID: Int64) async throws {
		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

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

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}
