//
//  CloudKitAppDelegate.swift
//  Account
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import ErrorLog
import SystemConfiguration
import os
import ActivityLog
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import Articles
import ArticlesDatabase
import Secrets
import CloudKitSync
import FeedFinder

/// Parameters: (error, operation, fileName, functionName, lineNumber)
typealias CloudKitSyncErrorHandler = @Sendable (Error, String, String, String, Int) -> Void

enum CloudKitAccountDelegateError: LocalizedError, Sendable {
	case invalidParameter
	case unknown

	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

@MainActor final class CloudKitAccountDelegate: AccountDelegate {
	nonisolated private static let logger = cloudKitLogger

	private let syncDatabase: SyncDatabase

	private let container: CKContainer = {
		let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as! String
		return CKContainer(identifier: "iCloud.\(orgID).NetNewsWire")
	}()

	private let accountZone: CloudKitAccountZone
	private let articlesZone: CloudKitArticlesZone
	private let syncArticleContentForUnreadArticles: @Sendable () -> Bool

	private let mainThreadOperationQueue = MainThreadOperationQueue()
	private let refresher: LocalAccountRefresher
	private var syncErrorHandler: CloudKitSyncErrorHandler?

	private var lastNoChangeSyncDate: Date?
	private static let noChangeBackoffInterval: TimeInterval = 30 * 60

	weak var account: Account?

	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false

	let server: String? = nil
	var credentials: Credentials?
	var accountSettings: AccountSettings?

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	private let syncProgress = RSProgress()
	private var syncProgressInfo = ProgressInfo() {
		didSet {
			updateProgress()
		}
	}

	private var refreshProgressInfo = ProgressInfo() {
		didSet {
			updateProgress()
		}
	}

	init(dataFolder: String) {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		let syncArticleContentForUnreadArticles: @Sendable () -> Bool = {
			UserDefaults.standard.bool(forKey: AccountManager.syncArticleContentForUnreadArticlesKey)
		}
		self.syncArticleContentForUnreadArticles = syncArticleContentForUnreadArticles
		self.accountZone = CloudKitAccountZone(container: container)
		self.articlesZone = CloudKitArticlesZone(container: container, syncArticleContentForUnreadArticles: syncArticleContentForUnreadArticles)

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		self.refresher = LocalAccountRefresher()
		self.refresher.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .progressInfoDidChange, object: refresher)
		NotificationCenter.default.addObserver(self, selector: #selector(syncProgressDidChange(_:)), name: .progressInfoDidChange, object: syncProgress)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
		guard let account else {
			return
		}
		lastNoChangeSyncDate = nil
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		ActivityLog.shared.logCompletedActivity(owner: account.activityOwner, kind: .receiveCloudKitNotification)

		await withCheckedContinuation { continuation in
			let op = CloudKitRemoteNotificationOperation(accountZone: accountZone, articlesZone: articlesZone, accountID: account.accountID, accountDisplayName: account.nameForDisplay, userInfo: userInfo)
			op.completionBlock = { _ in
				Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
				continuation.resume()
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		guard refreshProgressInfo.isComplete else {
			return
		}

		syncProgress.reset()

		guard NetworkMonitor.shared.isConnected else {
			return
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		try await standardRefreshAll(for: account)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")

		if let lastNoChangeSyncDate, Date().timeIntervalSince(lastNoChangeSyncDate) < Self.noChangeBackoffInterval {
			Self.logger.debug("CloudKitAccountDelegate: Skipping sync — no changes on last check, backing off")
			return false
		}

		let sentCount = try await sendArticleStatus(account: account, showProgress: false)
		try await refreshArticleStatus()

		let didReceiveChanges = !(articlesZoneHasNoChanges && accountZoneHasNoChanges)
		let didWork = sentCount > 0 || didReceiveChanges
		if didWork {
			lastNoChangeSyncDate = nil
		} else {
			lastNoChangeSyncDate = Date()
		}

		await cleanUpContentRecordsIfNeeded()
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		return didWork
	}

	private var articlesZoneHasNoChanges: Bool {
		guard let delegate = articlesZone.delegate as? CloudKitArticlesZoneDelegate else {
			return true
		}
		return delegate.lastChangedCount == 0 && delegate.lastDeletedCount == 0
	}

	private var accountZoneHasNoChanges: Bool {
		guard let delegate = accountZone.delegate as? CloudKitAcountZoneDelegate else {
			return true
		}
		return delegate.lastChangedCount == 0 && delegate.lastDeletedCount == 0
	}

	func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		_ = try await sendArticleStatus(account: account, showProgress: false)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let op = CloudKitReceiveStatusOperation(articlesZone: articlesZone, accountID: account.accountID, accountDisplayName: account.nameForDisplay)
			op.completionBlock = { mainThreadOperation in
				Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
				if mainThreadOperation.isCanceled {
					continuation.resume(throwing: CloudKitAccountDelegateError.unknown)
				} else {
					continuation.resume(returning: ())
				}
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func importOPML(opmlFile: URL) async throws {
		guard let account else {
			return
		}
		guard refreshProgressInfo.isComplete else {
			return
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		let opmlData = try Data(contentsOf: opmlFile)
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		let opmlDocument = try OPMLParser.parseOPML(with: parserData)

		// TODO: throw appropriate error if OPML file is empty.
		guard let opmlItems = opmlDocument.children, let rootExternalID = account.externalID else {
			return
		}
		let normalizedItems = OPMLNormalizer.normalize(opmlItems)

		syncProgress.addTask()
		defer {
			syncProgress.completeTask()
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}

		do {
			try await account.logActivity(kind: .importOPML, detail: opmlFile.lastPathComponent) {
				try await accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
			}
			try? await standardRefreshAll(for: account)
		} catch {
			postSyncError(error, account: account, operation: "Importing OPML")
			throw error
		}
	}

	@discardableResult
	func createFeed(url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) url: \(urlString)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete url: \(urlString)")
		}
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		let editedName = name == nil || name!.isEmpty ? nil : name
		return try await account.logActivity(kind: .subscribeFeed, detail: urlString) {
			try await createRSSFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed)
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		let editedName = name.isEmpty ? nil : name
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
			syncProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				try await accountZone.renameFeed(feed, editedName: editedName)
				feed.editedName = name
			}
		} catch {
			postSyncError(error, account: account, operation: "Renaming feed")
			throw error
		}
	}

	func removeFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
		}

		// Optimistic local removal — sidebar updates immediately.
		container.removeFeedFromTreeAtTopLevel(feed)

		do {
			try await account.logActivity(kind: .removeFeed, detail: feed.url) {
				try await removeFeedFromCloud(for: account, with: feed, from: container)
			}
		} catch CloudKitZoneError.corruptAccount {
			// Account is corrupt. Leave the feed removed locally to clear the bad state.
		} catch {
			container.addFeedToTreeAtTopLevel(feed)
			throw error
		}
	}

	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
			syncProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .moveFeed, detail: feed.url) {
				try await accountZone.moveFeed(feed, from: sourceContainer, to: destinationContainer)
				sourceContainer.removeFeedFromTreeAtTopLevel(feed)
				destinationContainer.addFeedToTreeAtTopLevel(feed)
			}
		} catch {
			postSyncError(error, account: account, operation: "Moving feed")
			throw error
		}
	}

	func addFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
			syncProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .addFeed, detail: feed.url) {
				try await accountZone.addFeed(feed, to: container)
				container.addFeedToTreeAtTopLevel(feed)
			}
		} catch {
			postSyncError(error, account: account, operation: "Adding feed")
			throw error
		}
	}

	func restoreFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
		}

		// The feed was already validated when first added. Skip Feed Finder and re-create the
		// CloudKit record directly, restoring the local tree position the user expects.
		syncProgress.addTask()

		container.addFeedToTreeAtTopLevel(feed)

		do {
			try await account.logActivity(kind: .restoreFeed, detail: feed.url) {
				let externalID = try await accountZone.createFeed(url: feed.url,
																  name: feed.name,
																  editedName: feed.editedName,
																  homePageURL: feed.homePageURL,
																  container: container)
				feed.externalID = externalID
			}
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			container.removeFeedFromTreeAtTopLevel(feed)
			postSyncError(error, account: account, operation: "Restoring feed")
			throw error
		}
	}

	func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) name: \(name)")
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete name: \(name)")
			syncProgress.completeTask()
		}

		do {
			return try await account.logActivity(kind: .createFolder, detail: name) {
				let externalID = try await accountZone.createFolder(name: name)
				guard let folder = account.ensureFolder(with: name) else {
					throw AccountError.invalidParameter
				}
				folder.externalID = externalID
				return folder
			}
		} catch {
			postSyncError(error, account: account, operation: "Creating folder")
			throw error
		}
	}

	func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) new name: \(name)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete new name: \(name)")
		}
		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		let oldName = folder.name ?? ""
		do {
			try await account.logActivity(kind: .renameFolder, detail: "\(oldName) → \(name)") {
				try await accountZone.renameFolder(folder, to: name)
				folder.name = name
			}
		} catch {
			postSyncError(error, account: account, operation: "Renaming folder")
			throw error
		}
	}

	func removeFolder(with folder: Folder) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) name: \(folder.name ?? "")")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete name: \(folder.name ?? "")")
		}

		let folderName = folder.name ?? ""
		let originalFeeds = folder.topLevelFeeds

		// Optimistic local removal — sidebar updates immediately.
		account.removeFolderFromTree(folder)

		try await account.logActivity(kind: .removeFolder, detail: folderName) {
			syncProgress.addTask()

			let feedExternalIDs: [String]
			do {
				feedExternalIDs = try await accountZone.findFeedExternalIDs(for: folder)
				syncProgress.completeTask()
			} catch {
				syncProgress.completeTask()
				syncProgress.completeTask()
				folder.replaceTopLevelFeeds(originalFeeds)
				account.addFolderToTree(folder)
				postSyncError(error, account: account, operation: "Removing folder")
				throw error
			}

			let feeds = feedExternalIDs.compactMap { account.existingFeed(withExternalID: $0) }
			var failedFeeds: Set<Feed> = []

			await withTaskGroup(of: (Feed, Error?).self) { group in
				for feed in feeds {
					group.addTask {
						do {
							try await account.logActivity(kind: .removeFeed, detail: feed.url) {
								try await self.removeFeedFromCloud(for: account, with: feed, from: folder)
							}
							return (feed, nil)
						} catch {
							Self.logger.error("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
							return (feed, error)
						}
					}
				}

				for await (feed, error) in group {
					if let error {
						failedFeeds.insert(feed)
						postSyncError(error, account: account, operation: "Removing folder")
					}
				}
			}

			guard failedFeeds.isEmpty else {
				// Best-effort restore: bring the folder back with only the feeds that failed to delete
				// from CloudKit. Successfully-removed feeds stay gone locally to match cloud state.
				syncProgress.completeTask()
				folder.replaceTopLevelFeeds(failedFeeds)
				account.addFolderToTree(folder)
				throw CloudKitAccountDelegateError.unknown
			}

			do {
				try await accountZone.removeFolder(folder)
				syncProgress.completeTask()
			} catch {
				syncProgress.completeTask()
				// All feeds were removed from CloudKit but the folder record removal failed.
				// Restore an empty folder locally so it matches the cloud and the user can retry.
				folder.replaceTopLevelFeeds([])
				account.addFolderToTree(folder)
				throw error
			}
		}
	}

	func restoreFolder(folder: Folder) async throws {
		guard let account else {
			throw AccountError.invalidParameter
		}
		guard let name = folder.name else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) name: \(name)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete name: \(name)")
		}

		let feedsToRestore = folder.topLevelFeeds
		syncProgress.addTasks(1 + feedsToRestore.count)

		do {
			try await account.logActivity(kind: .restoreFolder, detail: name) {
				let externalID = try await accountZone.createFolder(name: name)
				syncProgress.completeTask()

				folder.externalID = externalID
				account.addFolderToTree(folder)

				await withTaskGroup(of: Error?.self) { group in
					for feed in feedsToRestore {
						folder.topLevelFeeds.remove(feed)

						group.addTask {
							do {
								try await self.restoreFeed(feed: feed, container: folder)
								await self.syncProgress.completeTask()
								return nil
							} catch {
								Self.logger.error("CloudKit: Restore folder feed error: \(error.localizedDescription)")
								await self.syncProgress.completeTask()
								return error
							}
						}
					}

					for await error in group {
						if let error {
							postSyncError(error, account: account, operation: "Restoring folder")
						}
					}
				}

				account.addFolderToTree(folder)
			}
		} catch {
			syncProgress.completeTask()
			postSyncError(error, account: account, operation: "Restoring folder")
			throw error
		}
	}

	func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")

		let changedArticleIDs = await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(changedArticleIDs.map { articleID in
			SyncStatus(articleID: articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		await syncDatabase.insertStatuses(syncStatuses)
		if !syncStatuses.isEmpty {
			lastNoChangeSyncDate = nil
			NotificationCenter.default.post(name: .AccountDidQueueArticleStatuses, object: account)
		}
		if let count = await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus()
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func accountDidInitialize() {
		guard let account else {
			return
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")

		syncErrorHandler = { [weak self] error, operation, fileName, functionName, lineNumber in
			Task { @MainActor [weak self] in
				guard let self, let account = self.account else { return }
				self.postSyncError(error, account: account, operation: operation, fileName: fileName, functionName: functionName, lineNumber: lineNumber)
			}
		}

		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, articlesZone: articlesZone)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account, database: syncDatabase, articlesZone: articlesZone, syncErrorHandler: syncErrorHandler)

		let accountID = account.accountID
		let accountDisplayName = account.nameForDisplay
		func makePageHandler(kind: ActivityKind) -> CloudKitZoneFetchPageHandler {
			let what: String
			switch kind {
			case .refreshArticleStatuses:
				what = "status and content changes"
			case .refreshFeedList:
				what = "feed list changes"
			default:
				what = "changes"
			}
			return { _, changed, deleted, _ in
				let detail = "Fetching \(what) \(ActivityLog.shared.nextTaskNumberString())"
				let message = cloudKitSyncMessage(changed: changed, deleted: deleted)
				ActivityLog.shared.logCompletedActivity(owner: .account(accountID: accountID, displayName: accountDisplayName), kind: kind, detail: detail, message: message)
			}
		}
		accountZone.fetchChangesPageHandler = makePageHandler(kind: .refreshFeedList)
		articlesZone.fetchChangesPageHandler = makePageHandler(kind: .refreshArticleStatuses)

		syncDatabase.resetAllSelectedForProcessing()

		// Check to see if this is a new account and initialize anything we need
		if account.externalID == nil {
			Task {
				do {
					let externalID = try await accountZone.findOrCreateAccount()
					account.externalID = externalID
					try? await self.initialRefreshAll(for: account)
				} catch {
					Self.logger.error("CloudKitAccountDelegate: \(#function, privacy: .public) error: \(error.localizedDescription)")
					if let account = self.account {
						self.postSyncError(error, account: account, operation: "Creating account")
					}
				}
			}
			subscribeToZoneChangesWithActivity(account: account, zone: accountZone)
			subscribeToZoneChangesWithActivity(account: account, zone: articlesZone)
		}

	}

	func accountWillBeDeleted() {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		accountZone.resetChangeToken()
		articlesZone.resetChangeToken()
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		nil
	}

	func vacuumDatabases() async {
		guard let account else {
			return
		}
		await account.logActivity(kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(syncDatabase.databasePath)) {
			await syncDatabase.vacuum()
		}
	}

	func fetchCloudKitStats(progress: @escaping CloudKitStatsProgressHandler) async throws -> CloudKitStats {
		guard let account else {
			throw CloudKitAccountDelegateError.unknown
		}
		do {
			return try await account.logActivity(kind: .fetchCloudKitStats) {
				try await articlesZone.fetchStats(account: account, progress: progress)
			}
		} catch {
			Self.logger.error("CloudKitAccountDelegate: fetchCloudKitStats error: \(error)")
			postSyncError(error, account: account, operation: "Fetching iCloud stats")
			throw error
		}
	}

	func cleanUpCloudKit(dryRun: Bool, progress: @escaping @MainActor @Sendable (CloudKitCleanUpProgress) -> Void) async throws {
		guard let account else {
			throw CloudKitAccountDelegateError.unknown
		}
		let syncUnreadContent = AccountManager.shared.syncArticleContentForUnreadArticles
		let detail = dryRun ? "Dry run" : "Manual"
		do {
			try await account.logActivity(kind: .cleanUpCloudKitRecords, detail: detail) {
				try await articlesZone.cleanUpRecordsUsingCache(account: account, syncUnreadContent: syncUnreadContent, dryRun: dryRun, deleteStaleRecords: false, progress: progress)
			}
		} catch {
			Self.logger.error("CloudKitAccountDelegate: cleanUpCloudKit error: \(error)")
			postSyncError(error, account: account, operation: "Cleaning up iCloud records")
			throw error
		}
	}

	// MARK: - Suspend and Resume

	func suspendNetwork() {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		refresher.suspend()
	}

	func resume() {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		refresher.resume()
	}
}

// MARK: - Refresh Progress

private extension CloudKitAccountDelegate {

	func updateProgress() {
		progressInfo = ProgressInfo.combined([refreshProgressInfo, syncProgressInfo])
	}

	@objc func refreshProgressDidChange(_ note: Notification) {
		refreshProgressInfo = refresher.progressInfo
	}

	@objc func syncProgressDidChange(_ note: Notification) {
		syncProgressInfo = syncProgress.progressInfo
	}
}

// MARK: - Activity Log helper

private extension CloudKitAccountDelegate {

	/// Push-subscription setup runs once per zone at first iCloud account add.
	/// Wraps it in an activity so silent failures (offline, account issues) become
	/// visible — without it, a failed subscription means no future remote pushes.
	func subscribeToZoneChangesWithActivity(account: Account, zone: any CloudKitZone) {
		let zoneName = zone.zoneID.zoneName
		Task { [weak self] in
			guard let self else {
				return
			}
			do {
				try await account.logActivity(kind: .subscribeToCloudKitZone, detail: zoneName) {
					try await zone.subscribeToZoneChanges()
				}
			} catch {
				Self.logger.error("CloudKitAccountDelegate: subscribeToZoneChanges \(zoneName, privacy: .public) error: \(error.localizedDescription)")
				if let account = self.account {
					self.postSyncError(error, account: account, operation: "Subscribing to zone changes")
				}
			}
		}
	}
}

// MARK: - Private

private extension CloudKitAccountDelegate {

	func initialRefreshAll(for account: Account) async throws {
		try await performRefreshAll(for: account, sendArticleStatus: false)
	}

	func standardRefreshAll(for account: Account) async throws {
		try await performRefreshAll(for: account, sendArticleStatus: true)
	}

	func performRefreshAll(for account: Account, sendArticleStatus: Bool) async throws {
		lastNoChangeSyncDate = nil
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) sendArticleStatus: \(sendArticleStatus ? "true" : "false")")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}

		syncProgress.addTasks(3)

		let activityLog = ActivityLog.shared
		let owner = account.activityOwner

		// Overall .refreshAll activity for this account, wrapping every stage
		// below. Individual activities (fetchChangesInZone, receive/send operations)
		// log their own entries, while this one provides the account-is-refreshing
		// status at the account level.
		let refreshActivityID = activityLog.createActivity(owner: owner, kind: .refreshAll)
		activityLog.didStart(id: refreshActivityID)
		var refreshFinishedSuccessfully = false
		var refreshCompletionMessage: String?
		defer {
			if refreshFinishedSuccessfully {
				activityLog.didComplete(id: refreshActivityID, message: refreshCompletionMessage)
			} else {
				let error = NSError(domain: "CloudKitAccountDelegate", code: 0, userInfo: [NSLocalizedDescriptionKey: "Refresh interrupted"])
				activityLog.didFail(id: refreshActivityID, error: error)
			}
		}

		let fetchChangesDetail = "Fetching account zone changes \(activityLog.nextTaskNumberString())"

		do {
			try await activityLog.logActivity(owner: owner, kind: .refreshFeedList, detail: fetchChangesDetail) {
				try await accountZone.fetchChangesInZone()
			}
			syncProgress.completeTask()
		} catch {
			if case CloudKitZoneError.userDeletedZone = error {
				account.removeFeedsFromTreeAtTopLevel(account.topLevelFeeds)
				for folder in account.folders ?? Set<Folder>() {
					account.removeFolderFromTree(folder)
				}
			}
			postSyncError(error, account: account, operation: "Fetching zone changes")
			syncProgress.reset()
			throw error
		}

		let feeds = account.flattenedFeeds()

		do {
			try await refreshArticleStatus()
			syncProgress.completeTask()
		} catch {
			postSyncError(error, account: account, operation: "Refreshing article status")
			syncProgress.reset()
			throw error
		}

		refresher.accountID = account.accountID
		refresher.publishesRefreshActivity = false
		await refresher.refreshFeeds(feeds)
		refreshCompletionMessage = refresher.refreshStatsMessage

		if sendArticleStatus {
			do {
				_ = try await self.sendArticleStatus(account: account, showProgress: true)
			} catch {
				postSyncError(error, account: account, operation: "Sending article status")
				syncProgress.reset()
				throw error
			}
		}

		syncProgress.reset()
		account.lastRefreshCompletedDate = Date()
		refreshFinishedSuccessfully = true
	}

	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) url: \(url)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete url: \(url)")
		}
		syncProgress.addTasks(5)

		do {
			let feedSpecifiers = try await FeedFinder.find(url: url)
			syncProgress.completeTask()

			guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
				  let feedURL = URL(string: bestFeedSpecifier.urlString) else {
				syncProgress.completeTasks(3)
				if validateFeed {
					syncProgress.completeTask()
					throw AccountError.createErrorNotFound
				} else {
					return try await addDeadFeed(account: account, url: url, editedName: editedName, container: container)
				}
			}

			if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
				syncProgress.completeTasks(4)
				throw AccountError.createErrorAlreadySubscribed
			}

			return try await createAndSyncFeed(account: account,
											   feedURL: feedURL,
											   bestFeedSpecifier: bestFeedSpecifier,
											   editedName: editedName,
											   container: container)
		} catch {
			syncProgress.completeTasks(3)
			if validateFeed {
				syncProgress.completeTask()
				throw AccountError.createErrorNotFound
			} else {
				return try await addDeadFeed(account: account, url: url, editedName: editedName, container: container)
			}
		}
	}

	func createAndSyncFeed(account: Account, feedURL: URL, bestFeedSpecifier: FeedSpecifier, editedName: String?, container: Container) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feedURL: \(feedURL)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feedURL: \(feedURL)")
		}
		let feed = account.createFeed(with: nil, url: feedURL.absoluteString, feedID: feedURL.absoluteString, homePageURL: nil)
		feed.editedName = editedName
		container.addFeedToTreeAtTopLevel(feed)

		do {
			let parsedFeed = try await downloadAndParseFeed(feedURL: feedURL, feed: feed)
			try await updateAndCreateFeedInCloud(account: account,
												 feed: feed,
												 parsedFeed: parsedFeed,
												 bestFeedSpecifier: bestFeedSpecifier,
												 editedName: editedName,
												 container: container)
			return feed
		} catch {
			container.removeFeedFromTreeAtTopLevel(feed)
			syncProgress.completeTasks(3)
			throw error
		}
	}

	func downloadAndParseFeed(feedURL: URL, feed: Feed) async throws -> ParsedFeed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feedURL: \(feedURL)")
		let (parsedFeed, response) = try await InitialFeedDownloader.download(feedURL)
		syncProgress.completeTask()
		feed.lastCheckDate = Date()

		guard let parsedFeed else {
			throw AccountError.createErrorNotFound
		}

		// Save conditional GET info so that first refresh uses conditional GET.
		if let httpResponse = response as? HTTPURLResponse,
		   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
			feed.conditionalGetInfo = conditionalGetInfo
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		return parsedFeed
	}

	func updateAndCreateFeedInCloud(account: Account, feed: Feed, parsedFeed: ParsedFeed, bestFeedSpecifier: FeedSpecifier, editedName: String?, container: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		await account.updateAsync(feed: feed, parsedFeed: parsedFeed)

		let externalID = try await accountZone.createFeed(url: bestFeedSpecifier.urlString,
														  name: parsedFeed.title,
														  editedName: editedName,
														  homePageURL: parsedFeed.homePageURL,
														  container: container)
		syncProgress.completeTask()
		feed.externalID = externalID
		sendNewArticlesToTheCloud(account, feed)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func addDeadFeed(account: Account, url: URL, editedName: String?, container: Container) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		let feed = account.createFeed(with: editedName, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		container.addFeedToTreeAtTopLevel(feed)

		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
			syncProgress.completeTask()
		}

		do {
			let externalID = try await accountZone.createFeed(url: url.absoluteString,
															  name: editedName,
															  editedName: nil,
															  homePageURL: nil,
															  container: container)
			feed.externalID = externalID
			return feed
		} catch {
			container.removeFeedFromTreeAtTopLevel(feed)
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) error: \(error.localizedDescription)")
			throw error
		}
	}

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: Feed) {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		Task {
			do {
				let articles = await account.fetchArticlesAsync(.feed(feed))

				await storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>())
				syncProgress.completeTask()

				_ = try await sendArticleStatus(account: account, showProgress: true)

				do {
					try await articlesZone.fetchChangesInZone()
				} catch {
					Self.logger.error("CloudKitAccountDelegate: fetchChangesInZone error: \(error.localizedDescription)")
					if let account = self.account {
						postSyncError(error, account: account, operation: "Fetching zone changes")
					}
				}
			} catch {
				Self.logger.error("CloudKitAccountDelegate: \(#function, privacy: .public) error: \(error.localizedDescription)")
				if let account = self.account {
					postSyncError(error, account: account, operation: "Sending articles")
				}
			}
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}
	}

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}

	func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) async {
		// New records with a read status aren't really new, they just didn't have the read article stored
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		await withTaskGroup(of: Void.self) { group in
			if let new = new {
				let filteredNew = new.filter { $0.status.read == false }
				group.addTask {
					await self.insertSyncStatuses(articles: filteredNew, statusKey: .new, flag: true)
				}
			}

			group.addTask {
				await self.insertSyncStatuses(articles: updated, statusKey: .new, flag: false)
			}

			group.addTask {
				await self.insertSyncStatuses(articles: deleted, statusKey: .deleted, flag: true)
			}
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool) async {
		guard let articles = articles, !articles.isEmpty else {
			return
		}
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		})
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		await syncDatabase.insertStatuses(syncStatuses)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	/// Returns the number of statuses successfully sent.
	func sendArticleStatus(account: Account, showProgress: Bool) async throws -> Int {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
			let op = CloudKitSendStatusOperation(account: account,
												 articlesZone: articlesZone,
												 database: syncDatabase,
												 syncArticleContentForUnreadArticles: syncArticleContentForUnreadArticles,
												 syncErrorHandler: syncErrorHandler)
			op.completionBlock = { mainThreadOperation in
				Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
				if mainThreadOperation.isCanceled {
					continuation.resume(throwing: CloudKitAccountDelegateError.unknown)
				} else {
					continuation.resume(returning: op.sentCount)
				}
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func removeFeedFromCloud(for account: Account, with feed: Feed, from container: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}

		syncProgress.addTasks(2)

		do {
			_ = try await accountZone.removeFeed(feed, from: container)
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			syncProgress.completeTask()
			postSyncError(error, account: account, operation: "Removing feed")
			throw error
		}

		guard let feedExternalID = feed.externalID else {
			syncProgress.completeTask()
			return
		}

		do {
			try await articlesZone.deleteArticles(feedExternalID, owner: account.activityOwner)
			feed.dropConditionalGetInfo()
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			postSyncError(error, account: account, operation: "Removing feed articles")
			throw error
		}
	}

	// MARK: - Record Cleanup

	private static let lastCleanUpKey = "cloudkit.lastCleanUpDate"

	func cleanUpContentRecordsIfNeeded() async {
		if UserDefaults.standard.object(forKey: Self.lastCleanUpKey) == nil {
			UserDefaults.standard.set(Date(), forKey: Self.lastCleanUpKey)
			return
		}
		let lastCleanUp = UserDefaults.standard.object(forKey: Self.lastCleanUpKey) as? Date ?? .distantPast
		let sixDaysAgo = Date(timeIntervalSinceNow: -6 * 24 * 60 * 60)
		guard lastCleanUp < sixDaysAgo else {
			return
		}

		guard let account else {
			return
		}

		// Set this unconditionally. If it fails, we don’t want to keep trying, possibly
		// doing a bunch of extra work that will fail. Let it rest until the next go.
		UserDefaults.standard.set(Date(), forKey: Self.lastCleanUpKey)

		Self.logger.info("CloudKitAccountDelegate: running weekly record cleanup")
		do {
			let syncUnreadContent = AccountManager.shared.syncArticleContentForUnreadArticles
			let successMessage: (Int) -> String? = { count in
				count == 0 ? "no records deleted" : "deleted \(count) record\(count == 1 ? "" : "s")"
			}
			let deleted = try await account.logActivity(kind: .cleanUpCloudKitRecords, detail: "Weekly", successMessage: successMessage) { () -> Int in
				try await articlesZone.cleanUpRecords(account: account, syncUnreadContent: syncUnreadContent, dryRun: false, deleteStaleRecords: false)
			}
			Self.logger.info("CloudKitAccountDelegate: weekly cleanup deleted \(deleted, privacy: .public) records")
		} catch {
			Self.logger.error("CloudKitAccountDelegate: weekly cleanup error: \(error.localizedDescription, privacy: .public)")
			postSyncError(error, account: account, operation: "Weekly record cleanup")
		}
	}
}

extension CloudKitAccountDelegate: LocalAccountRefresherDelegate {

	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
		Task {
			await storeArticleChanges(new: articleChanges.new,
									  updated: articleChanges.updated,
									  deleted: articleChanges.deleted)
		}
	}
}
