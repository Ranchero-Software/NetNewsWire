//
//  ReaderAPIAccountDelegate.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
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
			return NSLocalizedString("There was an invalid response from the server.", comment: "Invalid response")
		case .urlNotFound:
			return NSLocalizedString("The API URL wasn't found.", comment: "The API URL wasn't found.")
		}
	}
}

final class ReaderAPIAccountDelegate: AccountDelegate {

	weak var account: Account?

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
		var behaviors: AccountBehaviors = [.disallowFeedInMultipleFolders]
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

	var accountSettings: AccountSettings? {
		didSet {
			caller.accountSettings = accountSettings
		}
	}

	init(dataFolder: String, variant: ReaderAPIVariant) {
		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databasePath)

		self.caller = ReaderAPICaller(logger: Self.logger)

		self.caller.variant = variant
		self.variant = variant

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		Self.logger.debug("ReaderAPIAccountDelegate: refreshAll")

		retrieveCredentialsIfNeeded(account)

		refreshProgress.addTasks(6)

		do {
			try await account.logActivity(kind: .refreshAll) {
				try await refreshAccount(account)

				try await sendArticleStatus()
				refreshProgress.completeTask()

				let articleIDs = try await account.logActivity(kind: .fetchArticleIDs, detail: "All articles", successMessage: { "\($0.count) article IDs" }, {
					try await caller.retrieveItemIDs(type: .allForAccount, pageHandler: articleIDPageHandler(for: account, kind: .fetchArticleIDs))
				})
				refreshProgress.completeTask()

				_ = await account.markAsReadAsync(articleIDs: Set(articleIDs))
				try? await refreshArticleStatus()
				refreshProgress.completeTask()

				await refreshMissingArticles(account)
				refreshProgress.reset()
			}
		} catch {
			Self.logger.error("ReaderAPIAccountDelegate: refreshAll 1 — error \(error.localizedDescription)")
			refreshProgress.reset()

			let wrappedError = AccountError.wrapped(error, account)
			if wrappedError.isCredentialsError, let basicCredentials = try? account.retrieveCredentials(type: .readerBasic), let endpoint = account.endpointURL {

				self.caller.credentials = basicCredentials

				do {
					if let apiCredentials = try await caller.validateCredentials(endpoint: endpoint) {
						try? account.storeCredentials(apiCredentials)
						caller.credentials = apiCredentials
						try await refreshAll()
						return
					}
					throw wrappedError
				} catch {
					Self.logger.error("ReaderAPIAccountDelegate: refreshAll 2 — error \(error.localizedDescription)")
					throw wrappedError
				}

			} else {
				throw wrappedError
			}
		}
	}

	@MainActor func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}
		guard variant != .inoreader else {
			// Inoreader: no-op for this delegate.
			return false
		}

		Self.logger.debug("ReaderAPIAccountDelegate: syncArticleStatus")

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

	/// Sends queued local status changes upstream. Returns the count successfully sent.
	private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.debug("ReaderAPIAccountDelegate: sendArticleStatus")

		return try await account.logActivity(kind: .sendArticleStatuses) { () -> Int in
			let syncStatuses = (await self.syncDatabase.selectForProcessing()) ?? Set<SyncStatus>()

			let createUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false }
			let deleteUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true }
			let createStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true }
			let deleteStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false }

			var sentCount = 0
			var savedError: Error?

			do {
				sentCount += try await sendArticleStatuses(createUnreadStatuses, account: account, label: "unread", apiCall: caller.createUnreadEntries)
			} catch {
				savedError = error
			}

			do {
				sentCount += try await sendArticleStatuses(deleteUnreadStatuses, account: account, label: "read", apiCall: caller.deleteUnreadEntries)
			} catch {
				savedError = error
			}

			do {
				sentCount += try await sendArticleStatuses(createStarredStatuses, account: account, label: "starred", apiCall: caller.createStarredEntries)
			} catch {
				savedError = error
			}

			do {
				sentCount += try await sendArticleStatuses(deleteStarredStatuses, account: account, label: "unstarred", apiCall: caller.deleteStarredEntries)
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

	/// Brings local read/starred statuses in line with the server. Returns the count
	/// of articles whose local state actually changed.
	@MainActor private func refreshArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.debug("ReaderAPIAccountDelegate: refreshArticleStatus")

		return try await account.logActivity(kind: .refreshArticleStatuses) { () -> Int in
			var changedCount = 0
			var errorOccurred = false

			let articleIDs = try await caller.retrieveItemIDs(type: .unread, pageHandler: articleIDPageHandler(for: account, kind: .refreshArticleStatuses))
			changedCount += await syncArticleReadState(account: account, articleIDs: articleIDs)

			do {
				let articleIDs = try await caller.retrieveItemIDs(type: .starred, pageHandler: articleIDPageHandler(for: account, kind: .refreshArticleStatuses))
				changedCount += await syncArticleStarredState(account: account, articleIDs: articleIDs)
			} catch {
				errorOccurred = true
				Self.logger.error("ReaderAPIAccountDelegate: refreshArticleStatus — retrieving starred entries failed: \(error.localizedDescription)")
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
		Self.logger.debug("ReaderAPIAccountDelegate: createFolder — name \(name)")

		return try account.logActivity(kind: .createFolder, detail: name) {
			guard let folder = account.ensureFolder(with: name) else {
				Self.logger.error("ReaderAPIAccountDelegate: createFolder failed — account.ensureFolder failed")
				throw AccountError.invalidParameter
			}
			return folder
		}
	}

	func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("ReaderAPIAccountDelegate: renameFolder — name \(folder.nameForDisplay) to \(name)")

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await account.logActivity(kind: .renameFolder, detail: "\(folder.name ?? "") → \(name)") {
				try await caller.renameTag(oldName: folder.name ?? "", newName: name)
				folder.externalID = "user/-/label/\(name)"
				folder.name = name
			}
		} catch {
			Self.logger.error("ReaderAPIAccountDelegate: renameFolder — error: \(error.localizedDescription)")
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
		Self.logger.debug("ReaderAPIAccountDelegate: removeFolder — name \(folder.nameForDisplay)")

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
						Self.logger.error("ReaderAPIAccountDelegate: removeFolder — remove feed 1 error: \(error.localizedDescription)")
						postSyncError(error, account: account, operation: "Removing feed from folder")
					}
				}

			} else {

				if let subscriptionID = feed.externalID {
					refreshProgress.addTask()

					do {
						try await caller.deleteSubscription(subscriptionID: subscriptionID)
						account.clearFeedSettings(feed)
						refreshProgress.completeTask()
					} catch {

						refreshProgress.completeTask()
						Self.logger.error("ReaderAPIAccountDelegate: removeFolder - remove feed 2 error: \(error.localizedDescription)")
						postSyncError(error, account: account, operation: "Removing feed from folder")
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
	func createFeed(url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		retrieveCredentialsIfNeeded(account)

		Self.logger.debug("ReaderAPIAccountDelegate: createFeed — url \(url) name \(name ?? "")")

		guard let url = URL(string: url) else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTasks(2)

		do {
			return try await account.logActivity(kind: .subscribeFeed, detail: url.absoluteString) {
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
			}
		} catch {
			Self.logger.error("ReaderAPIAccountDelegate: createFeed - error: \(error.localizedDescription)")
			refreshProgress.reset()
			throw AccountError.createErrorNotFound
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("ReaderAPIAccountDelegate: renameFeed — name \(feed.nameForDisplay) to name \(name)")

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			assert(feed.externalID != nil)
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				try await caller.renameSubscription(subscriptionID: subscriptionID, newName: name)
				feed.editedName = name
			}
			refreshProgress.completeTask()
		} catch {
			Self.logger.error("ReaderAPIAccountDelegate: renameFeed - error: \(error.localizedDescription)")
			refreshProgress.completeTask()
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("ReaderAPIAccountDelegate: removeFeed — url \(feed.url)")

		guard let subscriptionID = feed.externalID else {
			assert(feed.externalID != nil)
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask()}

		do {
			try await account.logActivity(kind: .removeFeed, detail: feed.url) {
				try await caller.deleteSubscription(subscriptionID: subscriptionID)
				account.clearFeedSettings(feed)
				account.removeAllInstancesOfFeedFromTreeAtAllLevels(feed)
			}
		} catch {
			Self.logger.error("ReaderAPIAccountDelegate: removeFeed - error: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("ReaderAPIAccountDelegate: moveFeed — url \(feed.url)")

		try await account.logActivity(kind: .moveFeed, detail: feed.url) {
			if sourceContainer is Account {
				try await addFeed(feed: feed, container: destinationContainer)
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
					Self.logger.error("ReaderAPIAccountDelegate: moveFeed - error: \(error.localizedDescription)")
					throw error
				}
			}
		}
	}

	func addFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("ReaderAPIAccountDelegate: addFeed — url \(feed.url)")

		try await account.logActivity(kind: .addFeed, detail: feed.url) {
			if let folder = container as? Folder, let feedExternalID = feed.externalID {

				refreshProgress.addTask()

				do {

					try await caller.createTagging(subscriptionID: feedExternalID, tagName: folder.name ?? "")

					self.saveFolderRelationship(for: feed, folderExternalID: folder.externalID, feedExternalID: feedExternalID)
					account.removeFeedFromTreeAtTopLevel(feed)
					folder.addFeedToTreeAtTopLevel(feed)

					refreshProgress.completeTask()

				} catch {
					Self.logger.error("ReaderAPIAccountDelegate: addFeed - error: \(error.localizedDescription)")
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
		Self.logger.debug("ReaderAPIAccountDelegate: restoreFeed — url \(feed.url)")

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
		Self.logger.debug("ReaderAPIAccountDelegate: restoreFolder — name \(folder.nameForDisplay)")

		await account.logActivity(kind: .restoreFolder, detail: folder.name ?? "") {
			for feed in folder.topLevelFeeds {

				folder.topLevelFeeds.remove(feed)

				do {
					try await restoreFeed(feed: feed, container: folder)
				} catch {
					Self.logger.error("ReaderAPIAccountDelegate: restoreFolder error: \(error.localizedDescription)")
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
		Self.logger.debug("ReaderAPIAccountDelegate: markArticles — statusKey \(statusKey.rawValue)")

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
	}

	func accountWillBeDeleted() {
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		Self.logger.debug("ReaderAPIAccountDelegate: validateCredentials")

		guard let endpoint else {
			throw WebserviceError.noURL
		}

		let caller = ReaderAPICaller(logger: Self.logger)
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

	/// Suspend all network activity
	func suspendNetwork() {
		Self.logger.debug("ReaderAPIAccountDelegate: suspendNetwork")

		caller.cancelAll()
	}

	/// Resume network activity after a previous `suspendNetwork()`.
	func resume() {
		Self.logger.debug("ReaderAPIAccountDelegate: resume")

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

private extension ReaderAPIAccountDelegate {

	func retrieveCredentialsIfNeeded(_ account: Account) {
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .readerAPIKey)
		}
	}

	@MainActor func refreshAccount(_ account: Account) async throws {
		Self.logger.debug("ReaderAPIAccountDelegate: refreshAccount")

		do {
			try await account.logActivity(kind: .refreshFeedList, successMessage: { "\($0.feeds) feeds, \($0.folders) folders" }, { () -> (folders: Int, feeds: Int) in
				let tags = try await caller.retrieveTags()
				refreshProgress.completeTask()

				let subscriptions = try await caller.retrieveSubscriptions()
				refreshProgress.completeTask()

				BatchUpdate.shared.perform {
					self.syncFolders(account, tags)
					self.syncFeeds(account, subscriptions)
					self.syncFeedFolderRelationship(account, subscriptions)
				}
				return (folders: tags?.count ?? 0, feeds: subscriptions?.count ?? 0)
			})
		} catch {
			postSyncError(error, account: account, operation: "Refreshing account")
			throw error
		}
	}

	/// Fetches one page or chunk of a paginated refresh as its own numbered, timed
	/// sub-activity of `kind`, reporting the page's item count.
	func logRefreshPage<T>(for account: Account, kind: ActivityKind, message: @escaping (T) -> String, _ fetch: () async throws -> T) async throws -> T {
		try await account.logActivity(kind: kind, detail: ActivityLog.shared.nextTaskNumberString(), successMessage: message, fetch)
	}

	/// Returns a per-page handler for paginated `retrieveItemIDs` calls, logging each
	/// page as a numbered sub-activity of `kind` reporting the page's article-ID count.
	func articleIDPageHandler(for account: Account, kind: ActivityKind) -> @MainActor (Int) -> Void {
		let owner = account.activityOwner
		return { count in
			let detail = ActivityLog.shared.nextTaskNumberString()
			ActivityLog.shared.logCompletedActivity(owner: owner, kind: kind, detail: detail, message: "\(count) article IDs")
		}
	}

	@MainActor func syncFolders(_ account: Account, _ tags: [ReaderAPITag]?) {
		Self.logger.debug("ReaderAPIAccountDelegate: syncFolders")

		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		let folderTags: [ReaderAPITag]
		if variant == .inoreader {
			folderTags = tags.filter { $0.type == "folder" }
		} else {
			folderTags = tags.filter { $0.tagID.contains("/label/") }
		}

		guard !folderTags.isEmpty else { return }

		let readerFolderExternalIDs = folderTags.compactMap { $0.tagID }

		// Delete any folders not at Reader
		if let folders = account.folders {
			for folder in folders {
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
		for tag in folderTags {
			if !folderExternalIDs.contains(tag.tagID) {
				let folder = account.ensureFolder(with: tag.folderName ?? "None")
				folder?.externalID = tag.tagID
			}
		}
	}

	@MainActor func syncFeeds(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		Self.logger.debug("ReaderAPIAccountDelegate: syncFeeds — subscriptions.count \(subscriptions?.count ?? -1)")

		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		let subFeedIds = subscriptions.map { $0.feedID }

		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						account.clearFeedSettings(feed)
						folder.removeFeedFromTreeAtTopLevel(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				account.clearFeedSettings(feed)
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		for subscription in subscriptions {
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
		Self.logger.debug("ReaderAPIAccountDelegate: syncFeedFolderRelationship — subscriptions.count \(subscriptions?.count ?? -1)")

		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		// Set up some structures to make syncing easier
		let folderDict = externalIDToFolderDictionary(with: account.folders)
		let taggingsDict = subscriptions.reduce([String: [ReaderAPISubscription]]()) { (dict, subscription) in
			var taggedFeeds = dict

			for category in subscription.categories {
				if var taggedFeed = taggedFeeds[category.categoryId] {
					taggedFeed.append(subscription)
					taggedFeeds[category.categoryId] = taggedFeed
				} else {
					taggedFeeds[category.categoryId] = [subscription]
				}
			}

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

	func sendArticleStatuses(_ statuses: Set<SyncStatus>, account: Account, label: String, apiCall: ([String]) async throws -> Void) async throws -> Int {
		Self.logger.debug("ReaderAPIAccountDelegate: sendArticleStatuses")

		guard !statuses.isEmpty else {
			return 0
		}

		let articleIDs = statuses.compactMap { $0.articleID }

		// Article IDs that can't be encoded for this server can never be sent — they would
		// fail every sync forever, churning the database. Delete them instead of retrying.
		let unsendableArticleIDs = Set(articleIDs.filter { !articleIDIsSendable($0) })
		if !unsendableArticleIDs.isEmpty {
			Self.logger.error("ReaderAPIAccountDelegate: dropping \(unsendableArticleIDs.count) unsendable article IDs from the status queue")
			await syncDatabase.deleteSelectedForProcessing(unsendableArticleIDs)
		}
		let sendableArticleIDs = articleIDs.filter { articleIDIsSendable($0) }

		var sentCount = 0
		var savedError: Error?
		let articleIDGroups = sendableArticleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {

			do {
				try await logRefreshPage(for: account, kind: .sendArticleStatuses, message: { _ in "\(articleIDGroup.count) \(label)" }, { try await apiCall(articleIDGroup) })
				await syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup))
				sentCount += articleIDGroup.count
			} catch {
				savedError = error
				Self.logger.error("ReaderAPIAccountDelegate: sendArticleStatuses — error \(error.localizedDescription)")
				await syncDatabase.resetSelectedForProcessing(Set(articleIDGroup))
			}
		}

		if let savedError {
			throw savedError
		}
		return sentCount
	}

	/// Whether an article ID can be encoded for this server's edit-tag API. Mirrors the
	/// ID encoding in ReaderAPICaller.updateStateToEntries.
	private func articleIDIsSendable(_ articleID: String) -> Bool {
		if variant == .theOldReader {
			return true
		}
		return Int(articleID) != nil
	}

	func clearFolderRelationship(for feed: Feed, folderExternalID: String?) {
		Self.logger.debug("ReaderAPIAccountDelegate: clearFolderRelationship — \(feed.url) folderExternalID \(folderExternalID ?? "")")

		guard var folderRelationship = feed.folderRelationship, let folderExternalID = folderExternalID else { return }
		folderRelationship[folderExternalID] = nil
		feed.folderRelationship = folderRelationship
	}

	func saveFolderRelationship(for feed: Feed, folderExternalID: String?, feedExternalID: String) {
		Self.logger.debug("ReaderAPIAccountDelegate: saveFolderRelationship — \(feed.url) folderExternalID \(folderExternalID ?? "") feedExternalID \(feedExternalID)")
		guard let folderExternalID = folderExternalID else { return }
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderExternalID] = feedExternalID
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderExternalID: feedExternalID]
		}
	}

	@MainActor func createFeed(account: Account, subscription: ReaderAPISubscription, name: String?, container: Container) async throws -> Feed {
		Self.logger.debug("ReaderAPIAccountDelegate: createFeed — \(subscription.feedID) name \(name ?? "")")

		let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
		feed.externalID = String(subscription.feedID)

		try await account.addFeed(feed, container: container)
		if let name {
			try await renameFeed(with: feed, to: name)
		}
		try await initialFeedDownload(account: account, feed: feed)

		return feed
	}

	@discardableResult
	func initialFeedDownload( account: Account, feed: Feed) async throws -> Feed {
		Self.logger.debug("ReaderAPIAccountDelegate: initialFeedDownload — \(feed.url)")

		refreshProgress.addTasks(5)

		try await account.logActivity(kind: .refreshFeedContent(feedURL: feed.url), detail: feed.nameForDisplay) {
			// Download the initial articles
			let articleIDs = try await caller.retrieveItemIDs(type: .allForFeed, feedID: feed.feedID, pageHandler: articleIDPageHandler(for: account, kind: .fetchArticleIDs))

			refreshProgress.completeTask()

			_ = await account.markAsReadAsync(articleIDs: Set(articleIDs))
			refreshProgress.completeTask()

			try? await refreshArticleStatus()
			refreshProgress.completeTask()

			await refreshMissingArticles(account)
			refreshProgress.reset()
		}

		return feed
	}

	func refreshMissingArticles(_ account: Account) async {
		Self.logger.debug("ReaderAPIAccountDelegate: refreshMissingArticles")

		await account.logActivity(kind: .refreshMissingArticles) {
			let fetchedArticleIDs = await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()

			if fetchedArticleIDs.isEmpty {
				return
			}

			Self.logger.info("ReaderAPI: Refreshing missing articles")

			let articleIDs = Array(fetchedArticleIDs)
			let chunkedArticleIDs = articleIDs.chunked(into: 150)

			refreshProgress.addTasks(chunkedArticleIDs.count + 1)

			for chunk in chunkedArticleIDs {

				do {
					let entries = try await logRefreshPage(for: account, kind: .refreshMissingArticles, message: { "\($0?.count ?? 0) articles" }, { try await caller.retrieveEntries(articleIDs: chunk) })
					refreshProgress.completeTask()
					await processEntries(account: account, entries: entries)
				} catch {
					Self.logger.error("ReaderAPI: Refresh missing articles error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Refreshing missing articles")
				}
			}

			refreshProgress.completeTask()
			Self.logger.info("ReaderAPI: Finished refreshing missing articles")
		}
	}

	func processEntries(account: Account, entries: [ReaderAPIEntry]?) async {
		Self.logger.debug("ReaderAPIAccountDelegate: processEntries")

		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }

		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(account: Account, entries: [ReaderAPIEntry]?) -> Set<ParsedItem> {
		Self.logger.debug("ReaderAPIAccountDelegate: mapEntriesToParsedItems — entries.count \(entries?.count ?? 0)")

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

	func syncArticleReadState(account: Account, articleIDs: [String]?) async -> Int {
		Self.logger.debug("ReaderAPIAccountDelegate: syncArticleReadState — articleIDs.count \(articleIDs?.count ?? 0)")

		guard let articleIDs else {
			return 0
		}

		let pendingArticleIDs = (await self.syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()

		let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)

		let currentUnreadArticleIDs = await account.fetchUnreadArticleIDsAsync()

		// Mark articles as unread
		let deltaUnreadArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
		let markedUnread = await account.markAsUnreadAsync(articleIDs: deltaUnreadArticleIDs)

		// Mark articles as read
		let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
		let markedRead = await account.markAsReadAsync(articleIDs: deltaReadArticleIDs)

		return markedUnread.count + markedRead.count
	}

	func syncArticleStarredState(account: Account, articleIDs: [String]?) async -> Int {
		Self.logger.debug("ReaderAPIAccountDelegate: syncArticleStarredState — articleIDs.count \(articleIDs?.count ?? 0)")

		guard let articleIDs else {
			return 0
		}

		let pendingArticleIDs = (await self.syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()
		let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
		let currentStarredArticleIDs = await account.fetchStarredArticleIDsAsync()

		// Mark articles as starred
		let deltaStarredArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentStarredArticleIDs)
		let markedStarred = await account.markAsStarredAsync(articleIDs: deltaStarredArticleIDs)

		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
		let markedUnstarred = await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)

		return markedStarred.count + markedUnstarred.count
	}

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}
