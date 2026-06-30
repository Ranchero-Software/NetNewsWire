//
//  MinifluxAccountDelegate.swift
//  Account
//
//  Created by Ingmar Stein on 6/18/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ActivityLog
import Articles
import ErrorLog
import RSCore
import RSParser
import RSWeb
import FeedFinder
import SyncDatabase
import os
import Secrets

enum MinifluxAccountDelegateError: LocalizedError {
	case unknown
	case invalidParameter
	case invalidResponse
	case urlNotFound

	var errorDescription: String? {
		switch self {
		case .unknown:
			return NSLocalizedString("An unexpected error occurred.", comment: "An unexpected error occurred.")
		case .invalidParameter:
			return NSLocalizedString("An invalid parameter was passed.", comment: "An invalid parameter was passed.")
		case .invalidResponse:
			return NSLocalizedString("There was an invalid response from the server.", comment: "Invalid response")
		case .urlNotFound:
			return NSLocalizedString("The API URL wasn't found.", comment: "The API URL wasn't found.")
		}
	}
}

final class MinifluxAccountDelegate: AccountDelegate {

	weak var account: Account?

	private let syncDatabase: SyncDatabase
	private let caller: MinifluxCaller
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Miniflux")

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}
	let refreshProgress = RSProgress()

	/// Detected Miniflux server version, fetched during `accountDidInitialize`.
	var minifluxVersion: MinifluxVersion?

	var behaviors: AccountBehaviors {
		[.disallowFeedInMultipleFolders, .disallowFeedInRootFolder]
	}

	@MainActor var server: String? {
		caller.accountSettings?.endpointURL?.host
	}

	var isOPMLImportInProgress = false

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

	init(dataFolder: String) {
		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databasePath)

		self.caller = MinifluxCaller(logger: Self.logger)

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: refreshAll")

		retrieveCredentialsIfNeeded(account)

		refreshProgress.addTasks(5)

		do {
			try await account.logActivity(kind: .refreshAll) {
				try await refreshAccount(account)

				try await sendArticleStatus()
				refreshProgress.completeTask()

				let articleIDs = try await account.logActivity(kind: .fetchArticleIDs, detail: "All articles", successMessage: { "\($0.count) article IDs" }, {
					try await caller.retrieveEntryIDs(type: .all)
				})
				refreshProgress.completeTask()

				let stringArticleIDs = Set(articleIDs.map { String($0) })
				_ = await account.markAsReadAsync(articleIDs: stringArticleIDs)
				try? await refreshArticleStatus()
				refreshProgress.completeTask()

				await refreshMissingArticles(account)
				refreshProgress.reset()
			}
		} catch {
			Self.logger.error("MinifluxAccountDelegate: refreshAll — error \(error.localizedDescription)")
			refreshProgress.reset()
			throw AccountError.wrapped(error, account)
		}
	}

	@MainActor func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}

		Self.logger.debug("MinifluxAccountDelegate: syncArticleStatus")

		let sentCount = try await sendArticleStatusReturningCount(for: account)
		let refreshChangedCount = try await refreshArticleStatusReturningCount(for: account)
		return sentCount > 0 || refreshChangedCount > 0
	}

	public func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await sendArticleStatusReturningCount(for: account)
	}

	private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.debug("MinifluxAccountDelegate: sendArticleStatus")

		return try await account.logActivity(kind: .sendArticleStatuses) { () -> Int in
			let syncStatuses = (await syncDatabase.selectForProcessing()) ?? Set<SyncStatus>()

			let createUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false }
			let deleteUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true }
			let createStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true }
			let deleteStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false }

			var sentCount = 0
			var savedError: Error?

			do {
				let articleIDs = createUnreadStatuses.compactMap { Int($0.articleID) }
				if !articleIDs.isEmpty {
					try await caller.markEntriesUnread(entryIDs: articleIDs)
					sentCount += articleIDs.count
					await syncDatabase.deleteSelectedForProcessing(Set(createUnreadStatuses.map { $0.articleID }))
				}
			} catch {
				savedError = error
			}

			do {
				let articleIDs = deleteUnreadStatuses.compactMap { Int($0.articleID) }
				if !articleIDs.isEmpty {
					try await caller.markEntriesRead(entryIDs: articleIDs)
					sentCount += articleIDs.count
					await syncDatabase.deleteSelectedForProcessing(Set(deleteUnreadStatuses.map { $0.articleID }))
				}
			} catch {
				savedError = error
			}

			do {
				for status in createStarredStatuses {
					if let entryID = Int(status.articleID) {
						try await caller.toggleBookmark(entryID: entryID)
						sentCount += 1
						await syncDatabase.deleteSelectedForProcessing(Set([status.articleID]))
					}
				}
			} catch {
				savedError = error
			}

			do {
				for status in deleteStarredStatuses {
					if let entryID = Int(status.articleID) {
						try await caller.toggleBookmark(entryID: entryID)
						sentCount += 1
						await syncDatabase.deleteSelectedForProcessing(Set([status.articleID]))
					}
				}
			} catch {
				savedError = error
			}

			if let savedError {
				postSyncError(savedError, account: account, operation: "Sending article status")
				throw savedError
			}
			return sentCount
		}
	}

	@MainActor func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await refreshArticleStatusReturningCount(for: account)
	}

	@MainActor private func refreshArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.debug("MinifluxAccountDelegate: refreshArticleStatus")

		return try await account.logActivity(kind: .refreshArticleStatuses) { () -> Int in
			var changedCount = 0
			var errorOccurred = false

			let unreadIDs = try await caller.retrieveEntryIDs(type: .unread)
			changedCount += await syncArticleReadState(account: account, articleIDs: unreadIDs.map { String($0) })

			do {
				let starredIDs = try await caller.retrieveEntryIDs(type: .starred)
				changedCount += await syncArticleStarredState(account: account, articleIDs: starredIDs.map { String($0) })
			} catch {
				errorOccurred = true
				Self.logger.error("MinifluxAccountDelegate: refreshArticleStatus — retrieving starred entries failed: \(error.localizedDescription)")
			}

			if errorOccurred {
				let error = AccountError.unknown
				postSyncError(error, account: account, operation: "Refreshing article status")
				throw error
			}
			return changedCount
		}
	}

	@MainActor func importOPML(opmlFile: URL) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .importOPML, detail: opmlFile.lastPathComponent) {
			let opmlData = try Data(contentsOf: opmlFile)
			try await caller.importOPML(opmlData: opmlData)
		}
	}

	@MainActor func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("MinifluxAccountDelegate: createFolder — name \(name)")

		return try await account.logActivity(kind: .createFolder, detail: name) {
			let categoryID = try await caller.createCategory(name: name)

			guard let folder = account.ensureFolder(with: name) else {
				Self.logger.error("MinifluxAccountDelegate: createFolder failed — account.ensureFolder failed")
				throw AccountError.invalidParameter
			}
			folder.externalID = String(categoryID)
			return folder
		}
	}

	func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: renameFolder — name \(folder.nameForDisplay) to \(name)")

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await account.logActivity(kind: .renameFolder, detail: "\(folder.name ?? "") → \(name)") {
				guard let externalID = folder.externalID, let categoryID = Int(externalID) else {
					throw AccountError.invalidParameter
				}
				try await caller.renameCategory(id: categoryID, name: name)
				folder.name = name
			}
		} catch {
			Self.logger.error("MinifluxAccountDelegate: renameFolder — error: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFolder(with folder: Folder) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .removeFolder, detail: folder.name ?? "") {
			try await removeFolderImpl(for: account, with: folder)
		}
	}

	private func removeFolderImpl(for account: Account, with folder: Folder) async throws {
		Self.logger.debug("MinifluxAccountDelegate: removeFolder — name \(folder.nameForDisplay)")

		// In Miniflux, deleting a category does not delete the feeds in it.
		// The feeds become uncategorized. We should first move feeds out of the folder.

		for feed in folder.topLevelFeeds {
			if let feedExternalID = feed.externalID, let feedID = Int(feedExternalID) {
				refreshProgress.addTask()

				do {
					// Move feed to no category by updating without category_id
					try await caller.moveFeed(feedID: feedID, categoryID: 0)
					account.addFeedToTreeAtTopLevel(feed)
					clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					refreshProgress.completeTask()
				} catch {
					refreshProgress.completeTask()
					Self.logger.error("MinifluxAccountDelegate: removeFolder — move feed error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Removing feed from folder")
				}
			}
		}

		if let externalID = folder.externalID, let categoryID = Int(externalID) {
			try await caller.deleteCategory(id: categoryID)
		}
		account.removeFolderFromTree(folder)
	}

	@discardableResult
	func createFeed(url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		retrieveCredentialsIfNeeded(account)

		Self.logger.debug("MinifluxAccountDelegate: createFeed — url \(url) name \(name ?? "")")

		guard let url = URL(string: url) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTasks(2)

		do {
			return try await account.logActivity(kind: .subscribeFeed, detail: url.absoluteString) {
				// For Miniflux, we can use the discover endpoint or subscribe directly.
				// Try discover first, then fall back to direct subscription.
				let feedURL: String
				do {
					let results = try await caller.discoverFeeds(url: url.absoluteString)
					if let discovered = results?.first {
						feedURL = discovered.url
					} else {
						feedURL = url.absoluteString
					}
				} catch {
					feedURL = url.absoluteString
				}
				refreshProgress.completeTask()

				let categoryID: Int?
				if let folder = container as? Folder, let externalID = folder.externalID, let catID = Int(externalID) {
					categoryID = catID
				} else {
					categoryID = nil
				}

				let feedID = try await caller.createFeed(url: feedURL, categoryID: categoryID)
				refreshProgress.completeTask()

				// Now retrieve all feeds to find the one we just created
				let feeds = try await caller.retrieveFeeds()
				guard let createdFeed = feeds?.first(where: { $0.id == feedID }) else {
					throw AccountError.createErrorNotFound
				}

				return try await createFeed(account: account, minifluxFeed: createdFeed, name: name, container: container)
			}
		} catch {
			Self.logger.error("MinifluxAccountDelegate: createFeed - error: \(error.localizedDescription)")
			refreshProgress.reset()
			throw AccountError.createErrorNotFound
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: renameFeed — name \(feed.nameForDisplay) to name \(name)")

		guard let subscriptionID = feed.externalID, let feedID = Int(subscriptionID) else {
			assert(feed.externalID != nil)
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				try await caller.renameFeed(feedID: feedID, name: name)
				feed.editedName = name
			}
			refreshProgress.completeTask()
		} catch {
			Self.logger.error("MinifluxAccountDelegate: renameFeed - error: \(error.localizedDescription)")
			refreshProgress.completeTask()
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: removeFeed — url \(feed.url)")

		guard let subscriptionID = feed.externalID, let feedID = Int(subscriptionID) else {
			assert(feed.externalID != nil)
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
			Self.logger.error("MinifluxAccountDelegate: removeFeed - error: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: moveFeed — url \(feed.url)")

		try await account.logActivity(kind: .moveFeed, detail: feed.url) {
			guard let feedExternalID = feed.externalID, let feedID = Int(feedExternalID) else {
				throw AccountError.invalidParameter
			}

			refreshProgress.addTask()
			defer { refreshProgress.completeTask() }

			let categoryID: Int
			if let folder = destinationContainer as? Folder, let externalID = folder.externalID, let catID = Int(externalID) {
				categoryID = catID
			} else if destinationContainer is Account {
				// Moving to root — Miniflux doesn't support root, but we can try categoryID 0
				// Actually, Miniflux feeds must have a category. If moving to root, we keep existing.
				throw AccountError.invalidParameter
			} else {
				throw AccountError.invalidParameter
			}

			do {
				try await caller.moveFeed(feedID: feedID, categoryID: categoryID)
				sourceContainer.removeFeedFromTreeAtTopLevel(feed)
				destinationContainer.addFeedToTreeAtTopLevel(feed)
			} catch {
				Self.logger.error("MinifluxAccountDelegate: moveFeed - error: \(error.localizedDescription)")
				throw error
			}
		}
	}

	func addFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: addFeed — url \(feed.url)")

		try await account.logActivity(kind: .addFeed, detail: feed.url) {
			if let folder = container as? Folder, let feedExternalID = feed.externalID, let feedID = Int(feedExternalID), let folderExternalID = folder.externalID, let categoryID = Int(folderExternalID) {

				refreshProgress.addTask()

				do {
					try await caller.moveFeed(feedID: feedID, categoryID: categoryID)

					saveFolderRelationship(for: feed, folderExternalID: folder.externalID, feedExternalID: feedExternalID)
					account.removeFeedFromTreeAtTopLevel(feed)
					folder.addFeedToTreeAtTopLevel(feed)

					refreshProgress.completeTask()

				} catch {
					Self.logger.error("MinifluxAccountDelegate: addFeed - error: \(error.localizedDescription)")
					refreshProgress.completeTask()
					throw AccountError.wrapped(error, account)
				}
			} else {
				if let containerAccount = container as? Account {
					containerAccount.addFeedIfNotInAnyFolder(feed)
				}
			}
		}
	}

	func restoreFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: restoreFeed — url \(feed.url)")

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
		Self.logger.debug("MinifluxAccountDelegate: restoreFolder — name \(folder.nameForDisplay)")

		await account.logActivity(kind: .restoreFolder, detail: folder.name ?? "") {
			for feed in folder.topLevelFeeds {

				folder.topLevelFeeds.remove(feed)

				do {
					try await restoreFeed(feed: feed, container: folder)
				} catch {
					Self.logger.error("MinifluxAccountDelegate: restoreFolder error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Restoring feed to folder")
				}
			}

			account.addFolderToTree(folder)
		}
	}

	@MainActor func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("MinifluxAccountDelegate: markArticles — statusKey \(statusKey.rawValue)")

		let changedArticleIDs = await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(changedArticleIDs.map { articleID in
			SyncStatus(articleID: articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		await syncDatabase.insertStatuses(syncStatuses)
		if !syncStatuses.isEmpty {
			NotificationCenter.default.post(name: .AccountDidQueueArticleStatuses, object: account)
		}
		if let count = await syncDatabase.selectPendingCount(), count > 100 {
			try? await sendArticleStatus()
		}
	}

	func accountDidInitialize() {
		guard let account else {
			return
		}
		retrieveCredentialsIfNeeded(account)

		Task { @MainActor in
			do {
				self.minifluxVersion = try await caller.retrieveVersion()
				if let v = self.minifluxVersion {
					Self.logger.info("MinifluxAccountDelegate: detected Miniflux version \(v.version)")
					caller.supportsEntryIDsEndpoint = v.isAtLeast("2.3.2")
				}
			} catch {
				Self.logger.warning("MinifluxAccountDelegate: unable to retrieve Miniflux version: \(error.localizedDescription)")
			}
		}
	}

	func accountWillBeDeleted() {
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		Self.logger.debug("MinifluxAccountDelegate: validateCredentials")

		guard let endpoint else {
			throw WebserviceError.noURL
		}

		let caller = MinifluxCaller(logger: Self.logger)
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

	// MARK: Suspend and Resume (for iOS)

	func suspendNetwork() {
		Self.logger.debug("MinifluxAccountDelegate: suspendNetwork")
		caller.cancelAll()
	}

	func resume() {
		Self.logger.debug("MinifluxAccountDelegate: resume")
		if let account {
			retrieveCredentialsIfNeeded(account)
		}
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: Private

private extension MinifluxAccountDelegate {

	func retrieveCredentialsIfNeeded(_ account: Account) {
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .minifluxAPIKey)
		}
	}

	@MainActor func refreshAccount(_ account: Account) async throws {
		Self.logger.debug("MinifluxAccountDelegate: refreshAccount")

		do {
			try await account.logActivity(kind: .refreshFeedList, successMessage: { "\($0.feeds) feeds, \($0.folders) folders" }, { () -> (folders: Int, feeds: Int) in
				let categories = try await caller.retrieveCategories()
				refreshProgress.completeTask()

				let feeds = try await caller.retrieveFeeds()
				refreshProgress.completeTask()

				BatchUpdate.shared.perform {
					self.syncFolders(account, categories)
					self.syncFeeds(account, feeds)
					self.syncFeedFolderRelationship(account, feeds)
				}
				return (folders: categories?.count ?? 0, feeds: feeds?.count ?? 0)
			})
		} catch {
			postSyncError(error, account: account, operation: "Refreshing account")
			throw error
		}
	}

	func logRefreshPage<T>(for account: Account, kind: ActivityKind, message: @escaping (T) -> String, _ fetch: () async throws -> T) async throws -> T {
		try await account.logActivity(kind: kind, detail: ActivityLog.shared.nextTaskNumberString(), successMessage: message, fetch)
	}

	@MainActor func syncFolders(_ account: Account, _ categories: [MinifluxCategory]?) {
		Self.logger.debug("MinifluxAccountDelegate: syncFolders")

		guard let categories else { return }
		assert(Thread.isMainThread)

		guard !categories.isEmpty else { return }

		let categoryExternalIDs = categories.map { String($0.id) }

		// Delete any folders not on Miniflux
		if let folders = account.folders {
			for folder in folders {
				if !categoryExternalIDs.contains(folder.externalID ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeedToTreeAtTopLevel(feed)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					}
					account.removeFolderFromTree(folder)
				}
			}
		}

		let folderExternalIDs: [String] = {
			if let folders = account.folders {
				return folders.compactMap { $0.externalID }
			} else {
				return [String]()
			}
		}()

		// Create any categories we don't have locally
		for category in categories {
			let externalID = String(category.id)
			if !folderExternalIDs.contains(externalID) {
				let folder = account.ensureFolder(with: category.title)
				folder?.externalID = externalID
			}
		}
	}

	@MainActor func syncFeeds(_ account: Account, _ feeds: [MinifluxFeed]?) {
		Self.logger.debug("MinifluxAccountDelegate: syncFeeds — feeds.count \(feeds?.count ?? -1)")

		guard let feeds else { return }
		assert(Thread.isMainThread)

		let feedIDs = feeds.map { String($0.id) }

		// Remove any feeds that are no longer in the feed list
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !feedIDs.contains(feed.feedID) {
						account.clearFeedSettings(feed)
						folder.removeFeedFromTreeAtTopLevel(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !feedIDs.contains(feed.feedID) {
				account.clearFeedSettings(feed)
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		for feed in feeds {
			let feedID = String(feed.id)
			if let existingFeed = account.existingFeed(withFeedID: feedID) {
				existingFeed.name = feed.title
				existingFeed.editedName = nil
				existingFeed.homePageURL = feed.siteURL
			} else {
				let newFeed = account.createFeed(with: feed.title, url: feed.feedURL, feedID: feedID, homePageURL: feed.siteURL)
				newFeed.externalID = feedID
				account.addFeedToTreeAtTopLevel(newFeed)
			}
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ feeds: [MinifluxFeed]?) {
		Self.logger.debug("MinifluxAccountDelegate: syncFeedFolderRelationship — feeds.count \(feeds?.count ?? -1)")

		guard let feeds else { return }
		assert(Thread.isMainThread)

		let folderDict = externalIDToFolderDictionary(with: account.folders)

		// Build category to feeds mapping
		var categoryFeeds: [Int: [MinifluxFeed]] = [:]
		for feed in feeds {
			if let category = feed.category {
				categoryFeeds[category.id, default: []].append(feed)
			}
		}

		// Sync folders
		for (categoryID, feedList) in categoryFeeds {
			let categoryIDString = String(categoryID)
			guard let folder = folderDict[categoryIDString] else { continue }
			let categoryFeedIDs = feedList.map { String($0.id) }

			// Remove feeds not in this category
			for feed in folder.topLevelFeeds {
				if !categoryFeedIDs.contains(feed.feedID) {
					folder.removeFeedFromTreeAtTopLevel(feed)
					clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					account.addFeedToTreeAtTopLevel(feed)
				}
			}

			// Add feeds that should be in this category
			let folderFeedIDs = folder.topLevelFeeds.map { $0.feedID }
			for minifluxFeed in feedList {
				let stringID = String(minifluxFeed.id)
				if !folderFeedIDs.contains(stringID) {
					guard let feed = account.existingFeed(withFeedID: stringID) else {
						continue
					}
					saveFolderRelationship(for: feed, folderExternalID: categoryIDString, feedExternalID: stringID)
					folder.addFeedToTreeAtTopLevel(feed)
				}
			}
		}

		// Remove feeds from account root if they are in a category
		let categorizedFeedIDs = Set(feeds.filter { $0.category != nil }.map { String($0.id) })
		for feed in account.topLevelFeeds {
			if categorizedFeedIDs.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}
	}

	func externalIDToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders else {
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

	func clearFolderRelationship(for feed: Feed, folderExternalID: String?) {
		Self.logger.debug("MinifluxAccountDelegate: clearFolderRelationship — \(feed.url) folderExternalID \(folderExternalID ?? "")")

		guard var folderRelationship = feed.folderRelationship, let folderExternalID else { return }
		folderRelationship[folderExternalID] = nil
		feed.folderRelationship = folderRelationship
	}

	func saveFolderRelationship(for feed: Feed, folderExternalID: String?, feedExternalID: String) {
		Self.logger.debug("MinifluxAccountDelegate: saveFolderRelationship — \(feed.url) folderExternalID \(folderExternalID ?? "") feedExternalID \(feedExternalID)")
		guard let folderExternalID else { return }
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderExternalID] = feedExternalID
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderExternalID: feedExternalID]
		}
	}

	@MainActor func createFeed(account: Account, minifluxFeed: MinifluxFeed, name: String?, container: Container) async throws -> Feed {
		Self.logger.debug("MinifluxAccountDelegate: createFeed — \(minifluxFeed.id) name \(name ?? "")")

		let feedID = String(minifluxFeed.id)
		let feed = account.createFeed(with: minifluxFeed.title, url: minifluxFeed.feedURL, feedID: feedID, homePageURL: minifluxFeed.siteURL)
		feed.externalID = feedID

		try await account.addFeed(feed, container: container)
		if let name {
			try await renameFeed(with: feed, to: name)
		}
		try await initialFeedDownload(account: account, feed: feed)

		return feed
	}

	@discardableResult
	func initialFeedDownload(account: Account, feed: Feed) async throws -> Feed {
		Self.logger.debug("MinifluxAccountDelegate: initialFeedDownload — \(feed.url)")

		refreshProgress.addTasks(4)

		try await account.logActivity(kind: .refreshFeedContent(feedURL: feed.url), detail: feed.nameForDisplay) {
			// Download initial articles for the feed
			// We fetch recent entries and mark them as read since they're already existing
			let articleIDs = try await caller.retrieveEntryIDs(type: .all)
			refreshProgress.completeTask()

			let stringArticleIDs = Set(articleIDs.map { String($0) })
			_ = await account.markAsReadAsync(articleIDs: stringArticleIDs)
			refreshProgress.completeTask()

			try? await refreshArticleStatus()
			refreshProgress.completeTask()

			await refreshMissingArticles(account)
			refreshProgress.reset()
		}

		return feed
	}

	func refreshMissingArticles(_ account: Account) async {
		Self.logger.debug("MinifluxAccountDelegate: refreshMissingArticles")

		await account.logActivity(kind: .refreshMissingArticles) {
			let fetchedArticleIDs = await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()

			if fetchedArticleIDs.isEmpty {
				return
			}

			Self.logger.info("Miniflux: Refreshing missing articles")

			let articleIDs = Array(fetchedArticleIDs)
			let chunkedArticleIDs = articleIDs.chunked(into: 150)
			let intChunks = chunkedArticleIDs.map { chunk in
				chunk.compactMap { Int($0) }
			}

			refreshProgress.addTasks(intChunks.count + 1)

			for chunk in intChunks {
				guard !chunk.isEmpty else {
					refreshProgress.completeTask()
					continue
				}

				do {
					let entries = try await logRefreshPage(for: account, kind: .refreshMissingArticles, message: { "\($0?.count ?? 0) articles" }, { try await caller.retrieveEntries(articleIDs: chunk) })
					refreshProgress.completeTask()
					await processEntries(account: account, entries: entries)
				} catch {
					Self.logger.error("Miniflux: Refresh missing articles error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Refreshing missing articles")
				}
			}

			refreshProgress.completeTask()
			Self.logger.info("Miniflux: Finished refreshing missing articles")
		}
	}

	func processEntries(account: Account, entries: [MinifluxEntry]?) async {
		Self.logger.debug("MinifluxAccountDelegate: processEntries")

		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }

		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(account: Account, entries: [MinifluxEntry]?) -> Set<ParsedItem> {
		Self.logger.debug("MinifluxAccountDelegate: mapEntriesToParsedItems — entries.count \(entries?.count ?? 0)")

		guard let entries else {
			return Set<ParsedItem>()
		}

		let parsedItems: [ParsedItem] = entries.compactMap { entry in
			var authors: Set<ParsedAuthor>? {
				guard let name = entry.author else {
					return nil
				}
				return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
			}

			let datePublished: Date? = {
				return ISO8601DateFormatter().date(from: entry.publishedAt)
			}()

			return ParsedItem(syncServiceID: String(entry.id),
							  uniqueID: String(entry.id),
							  feedURL: String(entry.feed.id),
							  url: nil,
							  externalURL: entry.url,
							  title: entry.title,
							  language: nil,
							  contentHTML: entry.content,
							  contentText: nil,
							  markdown: nil,
							  summary: entry.content,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: datePublished,
							  dateModified: nil,
							  authors: authors,
							  tags: nil,
							  attachments: nil)
		}

		return Set(parsedItems)
	}

	func syncArticleReadState(account: Account, articleIDs: [String]?) async -> Int {
		Self.logger.debug("MinifluxAccountDelegate: syncArticleReadState — articleIDs.count \(articleIDs?.count ?? 0)")

		guard let articleIDs else {
			return 0
		}

		let pendingArticleIDs = (await syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()
		let updatableUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
		let currentUnreadArticleIDs = await account.fetchUnreadArticleIDsAsync()

		// Mark articles as unread
		let deltaUnreadArticleIDs = updatableUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
		let markedUnread = await account.markAsUnreadAsync(articleIDs: deltaUnreadArticleIDs)

		// Mark articles as read
		let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableUnreadArticleIDs)
		let markedRead = await account.markAsReadAsync(articleIDs: deltaReadArticleIDs)

		return markedUnread.count + markedRead.count
	}

	func syncArticleStarredState(account: Account, articleIDs: [String]?) async -> Int {
		Self.logger.debug("MinifluxAccountDelegate: syncArticleStarredState — articleIDs.count \(articleIDs?.count ?? 0)")

		guard let articleIDs else {
			return 0
		}

		let pendingArticleIDs = (await syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()
		let updatableStarredArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
		let currentStarredArticleIDs = await account.fetchStarredArticleIDsAsync()

		// Mark articles as starred
		let deltaStarredArticleIDs = updatableStarredArticleIDs.subtracting(currentStarredArticleIDs)
		let markedStarred = await account.markAsStarredAsync(articleIDs: deltaStarredArticleIDs)

		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableStarredArticleIDs)
		let markedUnstarred = await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)

		return markedStarred.count + markedUnstarred.count
	}

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}
