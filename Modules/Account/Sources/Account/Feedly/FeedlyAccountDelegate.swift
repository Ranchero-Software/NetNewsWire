//
//  FeedlyAccountDelegate.swift
//  Account
//
//  Created by Kiel Gillard on 3/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ActivityLog
import Articles
import ErrorLog
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os
import Secrets

@MainActor final class FeedlyAccountDelegate: AccountDelegate {

	/// Feedly has a sandbox API and a production API.
	/// This property is referred to when clients need to know which environment it should be pointing to.
	/// The value of this property must match any `OAuthAuthorizationClient` used.
	/// Currently this is always returning the cloud API, but we are leaving it stubbed out for now.
	nonisolated static var environment: FeedlyAPICaller.API {
		return .cloud
	}

	// TODO: Kiel, if you decide not to support OPML import you will have to disallow it in the behaviors
	// See https://developer.feedly.com/v3/opml/
	var behaviors: AccountBehaviors = [.disallowFeedInRootFolder, .disallowMarkAsUnreadAfterPeriod(31)]

	let isOPMLImportSupported = false
	var isOPMLImportInProgress = false

	var server: String? {
		return caller.server
	}

	var credentials: Credentials? {
		didSet {
			#if DEBUG
			// https://developer.feedly.com/v3/developer/
			if let devToken = ProcessInfo.processInfo.environment["FEEDLY_DEV_ACCESS_TOKEN"], !devToken.isEmpty {
				caller.credentials = Credentials(type: .oauthAccessToken, username: "Developer", secret: devToken)
				return
			}
			#endif
			caller.credentials = credentials
		}
	}

	var accountSettings: AccountSettings?

	let oauthAuthorizationClient: OAuthAuthorizationClient
	let refreshProgress = RSProgress()

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	let caller: FeedlyAPICaller
	private let syncDatabase: SyncDatabase
	weak var account: Account?
	private static let logger = Feedly.logger

	private static let articleDownloadChunkSize = 1000
	private static let markChunkSize = 300 // Feedly /v3/markers limit
	private static let pendingStatusSendThreshold = 100

	private var lastNoChangeSyncDate: Date?
	private static let noChangeBackoffInterval: TimeInterval = 30 * 60

	init(dataFolder: String, api: FeedlyAPICaller.API) {

		self.caller = FeedlyAPICaller(api: api)

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)
		self.oauthAuthorizationClient = api.oauthAuthorizationClient

		self.caller.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	// MARK: - Account API

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: refreshAll")

		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
		}

		guard !Platform.isRunningUnitTests else {
			Self.logger.debug("FeedlyAccountDelegate: Ignoring refreshAll: running unit tests")
			return
		}

		guard let credentials else {
			Self.logger.info("FeedlyAccountDelegate: Ignoring refreshAll: account has no credentials")
			throw FeedlyAccountDelegateError.notLoggedIn
		}

		refreshProgress.reset()
		refreshProgress.addTasks(6)
		progressInfo = ProgressInfo()
		let startDate = Date()

		let successMessage: (RefreshAllSummary) -> String? = { summary in
			Self.refreshAllMessage(summary: summary)
		}

		do {
			try await account.logActivity(kind: .refreshAll, successMessage: successMessage) { () -> RefreshAllSummary in
				var summary = RefreshAllSummary()
				summary.statusesSent = try await sendArticleStatusReturningCount(for: account)
				refreshProgress.completeTask()
				summary.feedListChanges = try await refreshFeedList(for: account)
				refreshProgress.completeTask()
				try await ingestStreamArticleIDs(for: account, userID: credentials.username)
				refreshProgress.completeTask()
				summary.statusRefreshCounts = try await refreshArticleStatusReturningCounts(for: account)
				refreshProgress.completeTask()
				let updatedIDs = try await updatedArticleIDs(for: account, userID: credentials.username, newerThan: accountSettings?.lastArticleFetchStartTime)
				let missingIDs = await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
				refreshProgress.completeTask()
				summary.articlesDownloaded = try await downloadEntries(for: account, articleIDs: missingIDs.union(updatedIDs))
				refreshProgress.completeTask()
				return summary
			}
			accountSettings?.lastArticleFetchStartTime = startDate
			accountSettings?.lastRefreshCompletedDate = Date()
			Self.logger.debug("FeedlyAccountDelegate: Sync took \(-startDate.timeIntervalSinceNow, privacy: .public) seconds")
		} catch {
			refreshProgress.reset()
			progressInfo = ProgressInfo()
			throw AccountError.wrapped(error, account)
		}

		refreshProgress.reset()
		progressInfo = ProgressInfo()
	}

	func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}
		if let lastNoChangeSyncDate, Date().timeIntervalSince(lastNoChangeSyncDate) < Self.noChangeBackoffInterval {
			Self.logger.debug("Feedly: Skipping sync — no changes on last check, backing off")
			return false
		}

		refreshProgress.reset()
		refreshProgress.addTasks(2)
		progressInfo = ProgressInfo()
		defer {
			refreshProgress.reset()
			progressInfo = ProgressInfo()
		}

		let sentCount = try await sendArticleStatusReturningCount(for: account)
		refreshProgress.completeTask()
		let refreshCounts = try await refreshArticleStatusReturningCounts(for: account)
		refreshProgress.completeTask()

		if sentCount == 0 && refreshCounts.totalChanged == 0 {
			lastNoChangeSyncDate = Date()
		} else {
			lastNoChangeSyncDate = nil
		}

		return sentCount > 0 || refreshCounts.totalChanged > 0
	}

	func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await sendArticleStatusReturningCount(for: account)
	}

	/// Sends queued local status changes upstream. Returns the count successfully sent.
	private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.info("Feedly: Sending article statuses")
		defer {
			Self.logger.info("Feedly: Finished sending article statuses")
		}

		let successMessage: (Int) -> String? = { count in
			Self.sendStatusMessage(count: count)
		}
		let durationIsSignificant: (Int) -> Bool = { count in
			count > 0
		}

		do {
			return try await account.logActivity(kind: .sendArticleStatuses, successMessage: successMessage, durationIsSignificant: durationIsSignificant) { () -> Int in
				guard let syncStatuses = await syncDatabase.selectForProcessing() else {
					return 0
				}

				var savedError: Error?
				var sentCount = 0
				let pairings: [(key: SyncStatus.Key, flag: Bool, action: FeedlyMarkAction)] = [
					(.read, false, .unread),
					(.read, true, .read),
					(.starred, true, .saved),
					(.starred, false, .unsaved)
				]

				for pairing in pairings {
					let pending = syncStatuses.filter { $0.key == pairing.key && $0.flag == pairing.flag }
					guard !pending.isEmpty else {
						continue
					}
					let articleIDs = Set(pending.map { $0.articleID })
					do {
						for chunk in Array(articleIDs).chunked(into: Self.markChunkSize) {
							let chunkIDs = Set(chunk)
							try await logRefreshPage(for: account, kind: .sendArticleStatuses, message: { _ in "\(chunkIDs.count) \(pairing.action.rawValue)" }, { try await caller.mark(chunkIDs, as: pairing.action) })
						}
						await syncDatabase.deleteSelectedForProcessing(articleIDs)
						sentCount += articleIDs.count
					} catch {
						Self.logger.error("Feedly: Article status sync call failed: \(error.localizedDescription)")
						await syncDatabase.resetSelectedForProcessing(articleIDs)
						savedError = error
					}
				}

				if let savedError {
					throw savedError
				}
				return sentCount
			}
		} catch {
			postSyncError(error, account: account, operation: "Sending article status")
			throw error
		}
	}

	func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await refreshArticleStatusReturningCounts(for: account)
	}

	/// Attempt to bring local read/starred statuses in line with the remote ones.
	/// If the user is using another Feedly client at roughly the same time as this app,
	/// this app does its part to ensure articles have a consistent status between both.
	/// Returns counts of articles whose unread/starred state actually flipped.
	private func refreshArticleStatusReturningCounts(for account: Account) async throws -> StatusRefreshCounts {
		Self.logger.info("Feedly: Refreshing article statuses")

		guard let credentials else {
			return StatusRefreshCounts()
		}

		let successMessage: (StatusRefreshCounts) -> String? = { counts in
			Self.refreshStatusMessage(counts: counts)
		}
		let durationIsSignificant: (StatusRefreshCounts) -> Bool = { counts in
			counts.totalChanged > 0
		}

		return try await account.logActivity(kind: .refreshArticleStatuses, successMessage: successMessage, durationIsSignificant: durationIsSignificant) { () -> StatusRefreshCounts in
			var refreshError: Error?
			var counts = StatusRefreshCounts()

			do {
				let unread = try await ingestUnreadArticleIDs(for: account, userID: credentials.username)
				counts.unreadAdded = unread.added
				counts.unreadRemoved = unread.removed
			} catch {
				refreshError = error
				Self.logger.error("Feedly: Ingesting unread article IDs failed: \(error.localizedDescription)")
			}

			do {
				let starred = try await ingestStarredArticleIDs(for: account, userID: credentials.username)
				counts.starredAdded = starred.added
				counts.starredRemoved = starred.removed
			} catch {
				refreshError = error
				Self.logger.error("Feedly: Ingesting starred article IDs failed: \(error.localizedDescription)")
			}

			Self.logger.info("Feedly: Finished refreshing article statuses")
			if let refreshError {
				postSyncError(refreshError, account: account, operation: "Refreshing article status")
				throw refreshError
			}
			return counts
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

		Self.logger.info("Feedly: Did begin importing OPML")
		isOPMLImportInProgress = true
		refreshProgress.addTask()
		defer {
			isOPMLImportInProgress = false
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .importOPML, detail: opmlFile.lastPathComponent) {
				try await caller.importOPML(opmlData)
				Self.logger.info("Feedly: Finished importing OPML")
			}
		} catch {
			Self.logger.info("Feedly: OPML import failed: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("FeedlyAccountDelegate: createFolder")
		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		return try await account.logActivity(kind: .createFolder, detail: name) {
			let collection = try await caller.createCollection(named: name)
			guard let folder = account.ensureFolder(with: collection.label) else {
				// Is the name empty? Or one of the global resource names?
				throw FeedlyAccountDelegateError.unableToAddFolder(name)
			}
			folder.externalID = collection.id
			return folder
		}
	}

	func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: renameFolder")

		guard let id = folder.externalID else {
			throw FeedlyAccountDelegateError.unableToRenameFolder(folder.nameForDisplay, name)
		}

		let nameBefore = folder.name
		// Optimistically apply the new name; revert on failure.
		folder.name = name

		do {
			try await account.logActivity(kind: .renameFolder, detail: "\(nameBefore ?? "") → \(name)") {
				let collection = try await caller.renameCollection(with: id, to: name)
				folder.name = collection.label
			}
		} catch {
			folder.name = nameBefore
			throw error
		}
	}

	func removeFolder(with folder: Folder) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: removeFolder")

		guard let id = folder.externalID else {
			throw FeedlyAccountDelegateError.unableToRemoveFolder(folder.nameForDisplay)
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		try await account.logActivity(kind: .removeFolder, detail: folder.name ?? "") {
			try await caller.deleteCollection(with: id)
			account.removeFolderFromTree(folder)
		}
	}

	@discardableResult
	func createFeed(url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("FeedlyAccountDelegate: createFeed")

		guard let credentials else {
			throw FeedlyAccountDelegateError.notLoggedIn
		}

		let (folder, collectionID) = try folderAndCollectionID(for: container)

		refreshProgress.addTasks(5)
		defer {
			refreshProgress.completeTasks(5)
		}

		do {
			return try await account.logActivity(kind: .subscribeFeed, detail: urlString) {

				let searchResponse = try await caller.getFeeds(for: urlString, count: 1, locale: Locale.current.identifier)
				guard let firstResult = searchResponse.results.first else {
					throw AccountError.createErrorNotFound
				}
				let feedResource = FeedlyFeedResourceID(id: firstResult.feedID)

				let collectionFeeds = try await caller.addFeed(with: feedResource, title: name, toCollectionWith: collectionID)
				guard collectionFeeds.contains(where: { $0.id == feedResource.id }) else {
					throw AccountError.createErrorNotFound
				}

				syncFeedsForCollectionFolders([(collectionFeeds, folder)], in: account)

				try await ingestUnreadArticleIDs(for: account, userID: credentials.username)
				try await syncStreamContents(for: account, resource: feedResource, paginated: false, newerThan: nil)

				guard let feed = folder.existingFeed(withFeedID: feedResource.id) else {
					throw AccountError.createErrorNotFound
				}
				return feed
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: renameFeed")

		let folderCollectionIDs = account.folders?.filter { $0.has(feed) }.compactMap { $0.externalID }
		guard let collectionID = folderCollectionIDs?.first else {
			throw FeedlyAccountDelegateError.unableToRenameFeed(feed.nameForDisplay, name)
		}

		let editedNameBefore = feed.editedName
		// Optimistically set the name; revert on failure.
		feed.editedName = name

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				let feedResource = FeedlyFeedResourceID(id: feed.feedID)
				// Adding an existing feed updates it.
				// Updating a feed name in one folder/collection updates it for all folders/collections.
				_ = try await caller.addFeed(with: feedResource, title: name, toCollectionWith: collectionID)
			}
		} catch {
			feed.editedName = editedNameBefore
			throw error
		}
	}

	func addFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: addFeed")

		guard credentials != nil else {
			throw FeedlyAccountDelegateError.notLoggedIn
		}

		let (folder, collectionID) = try folderAndCollectionID(for: container)

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		try await account.logActivity(kind: .addFeed, detail: feed.url) {
			let resource = FeedlyFeedResourceID(id: feed.feedID)
			let collectionFeeds = try await caller.addFeed(with: resource, title: feed.editedName, toCollectionWith: collectionID)
			guard collectionFeeds.contains(where: { $0.id == resource.id }) else {
				throw AccountError.createErrorNotFound
			}
			syncFeedsForCollectionFolders([(collectionFeeds, folder)], in: account)
		}
	}

	func removeFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: removeFeed")

		guard let folder = container as? Folder, let collectionID = folder.externalID else {
			throw FeedlyAccountDelegateError.unableToRemoveFeed(feed.nameForDisplay)
		}

		// Optimistically remove the feed; restore on failure.
		folder.removeFeedFromTreeAtTopLevel(feed)

		do {
			try await account.logActivity(kind: .removeFeed, detail: feed.url) {
				try await caller.removeFeed(feed.feedID, fromCollectionWith: collectionID)
			}
		} catch {
			folder.addFeedToTreeAtTopLevel(feed)
			throw error
		}
	}

	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: moveFeed")

		guard let from = sourceContainer as? Folder, let to = destinationContainer as? Folder,
		      let fromCollectionID = from.externalID, let toCollectionID = to.externalID else {
			throw FeedlyAccountDelegateError.addFeedChooseFolder
		}

		let resource = FeedlyFeedResourceID(id: feed.feedID)

		try await account.logActivity(kind: .moveFeed, detail: feed.url) {
			// Optimistically move the feed.
			from.removeFeedFromTreeAtTopLevel(feed)
			to.addFeedToTreeAtTopLevel(feed)

			do {
				_ = try await caller.addFeed(with: resource, title: feed.editedName, toCollectionWith: toCollectionID)
			} catch {
				from.addFeedToTreeAtTopLevel(feed)
				to.removeFeedFromTreeAtTopLevel(feed)
				throw error
			}

			do {
				try await caller.removeFeed(feed.feedID, fromCollectionWith: fromCollectionID)
			} catch {
				from.addFeedToTreeAtTopLevel(feed)
				throw FeedlyAccountDelegateError.unableToMoveFeedBetweenFolders(feed.nameForDisplay, from.nameForDisplay, to.nameForDisplay)
			}
		}
	}

	func restoreFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: restoreFeed")

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			_ = try await createFeed(url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(folder: Folder) async throws {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: restoreFolder")

		await account.logActivity(kind: .restoreFolder, detail: folder.name ?? "") {
			for feed in folder.topLevelFeeds {

				folder.topLevelFeeds.remove(feed)

				do {
					try await restoreFeed(feed: feed, container: folder)
				} catch {
					Self.logger.error("Feedly: Restore folder feed error: \(error.localizedDescription)")
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
		Self.logger.debug("FeedlyAccountDelegate: markArticles")

		let changedArticleIDs = await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(changedArticleIDs.map { articleID in
			SyncStatus(articleID: articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		await syncDatabase.insertStatuses(syncStatuses)
		if !syncStatuses.isEmpty {
			lastNoChangeSyncDate = nil
			NotificationCenter.default.post(name: .AccountDidQueueArticleStatuses, object: account)
		}
		if let count = await syncDatabase.selectPendingCount(), count > Self.pendingStatusSendThreshold {
			try await sendArticleStatus()
		}
	}

	func accountDidInitialize() {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: accountDidInitialize")
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
	}

	func accountWillBeDeleted() {
		guard let account else {
			return
		}
		Self.logger.debug("FeedlyAccountDelegate: accountWillBeDeleted")

		// Capture `caller` so the logout outlives the delegate.
		Task { @MainActor [caller] in
			do {
				try await account.logActivity(kind: .validateCredentials, detail: "Logging out of Feedly") {
					try await caller.logout()
					try? account.removeCredentials(type: .oauthAccessToken)
					try? account.removeCredentials(type: .oauthRefreshToken)
				}
			} catch {
				Self.logger.error("Feedly: Logout failed: \(error.localizedDescription)")
			}
		}
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		Self.logger.debug("FeedlyAccountDelegate: validateCredentials")
		// Feedly accounts validate via the OAuth refresh-token flow rather than this entry point.
		assertionFailure("An account instance should refresh its access token instead of calling validateCredentials.")
		return credentials
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

	/// Suspend all network activity.
	func suspendNetwork() {
		Self.logger.debug("FeedlyAccountDelegate: suspendNetwork")
		caller.suspend()
	}

	/// Resume network activity after a previous `suspendNetwork()`.
	func resume() {
		Self.logger.debug("FeedlyAccountDelegate: resume")
		if let account, credentials == nil {
			credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
		}
		caller.resume()
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: - Sync Phases

private extension FeedlyAccountDelegate {

	/// Feedly requires feeds to live inside a folder (collection). Validate the container and
	/// pull out the folder plus its Feedly collection ID.
	func folderAndCollectionID(for container: Container) throws -> (folder: Folder, collectionID: String) {
		guard let folder = container as? Folder else {
			throw FeedlyAccountDelegateError.addFeedChooseFolder
		}
		guard let collectionID = folder.externalID else {
			throw FeedlyAccountDelegateError.addFeedInvalidFolder(folder.nameForDisplay)
		}
		return (folder, collectionID)
	}

	@discardableResult
	func refreshFeedList(for account: Account) async throws -> FeedListChanges {
		let successMessage: (FeedListChanges) -> String? = { changes in
			Self.feedListMessage(changes: changes)
		}
		let durationIsSignificant: (FeedListChanges) -> Bool = { changes in
			changes.totalChanged > 0
		}

		do {
			return try await account.logActivity(kind: .refreshFeedList, successMessage: successMessage, durationIsSignificant: durationIsSignificant) { () -> FeedListChanges in
				// Snapshot before reconciliation so we can diff what actually changed.
				let foldersBefore = account.folders ?? Set()
				let feedsBefore = account.flattenedFeeds()
				let feedNamesBefore = Dictionary(uniqueKeysWithValues: feedsBefore.map { ($0.feedID, $0.nameForDisplay) })

				let collections = try await caller.getCollections()
				let pairs = mirrorCollectionsAsFolders(collections, in: account)
				syncFeedsForCollectionFolders(pairs, in: account)

				let foldersAfter = account.folders ?? Set()
				let feedsAfter = account.flattenedFeeds()

				let feedsRenamed = feedsAfter.reduce(into: 0) { count, feed in
					if let before = feedNamesBefore[feed.feedID], before != feed.nameForDisplay {
						count += 1
					}
				}

				return FeedListChanges(
					foldersAdded: foldersAfter.subtracting(foldersBefore).count,
					foldersRemoved: foldersBefore.subtracting(foldersAfter).count,
					feedsAdded: feedsAfter.subtracting(feedsBefore).count,
					feedsRemoved: feedsBefore.subtracting(feedsAfter).count,
					feedsRenamed: feedsRenamed)
			}
		} catch {
			postSyncError(error, account: account, operation: "Refreshing feed list")
			throw error
		}
	}

	/// Pages through global.all stream IDs, creating a status for each so that downstream
	/// status sync has something to attach to.
	func ingestStreamArticleIDs(for account: Account, userID: String) async throws {
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		_ = try await account.logActivity(kind: .fetchArticleIDs, detail: "All articles", successMessage: { "\($0) article IDs" }, { () -> Int in
			var total = 0
			var continuation: String?
			repeat {
				let page = try await self.logRefreshPage(for: account, kind: .fetchArticleIDs, message: { "\($0.ids.count) article IDs" }, { try await self.caller.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil) })
				await account.createStatusesIfNeededAsync(articleIDs: Set(page.ids))
				total += page.ids.count
				continuation = page.continuation
			} while continuation != nil
			return total
		})
	}

	/// Mirror the remote unread set onto local statuses.
	/// Articles in the remote unread set become unread locally; the rest become read.
	/// Pending local edits are excluded so we don't temporarily clobber them.
	/// Returns counts of articles whose unread status actually flipped:
	/// `added` became unread, `removed` became read.
	@discardableResult
	func ingestUnreadArticleIDs(for account: Account, userID: String) async throws -> (added: Int, removed: Int) {
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		let remoteUnreadIDs = try await collectStreamIDs(for: account, resource: resource, kind: .refreshArticleStatuses, unreadOnly: true)

		let pendingArticleIDs = (await syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()
		let adjustedRemoteUnreadIDs = remoteUnreadIDs.subtracting(pendingArticleIDs)

		let localUnreadIDs = await account.fetchUnreadArticleIDsAsync()

		let newlyUnread = adjustedRemoteUnreadIDs.subtracting(localUnreadIDs)
		let toMarkRead = localUnreadIDs.subtracting(adjustedRemoteUnreadIDs)

		await account.markAsUnreadAsync(articleIDs: adjustedRemoteUnreadIDs)
		await account.markAsReadAsync(articleIDs: toMarkRead)

		return (added: newlyUnread.count, removed: toMarkRead.count)
	}

	/// Mirror the remote starred set onto local statuses.
	/// Returns counts of articles whose starred status actually flipped:
	/// `added` became starred, `removed` became unstarred.
	@discardableResult
	func ingestStarredArticleIDs(for account: Account, userID: String) async throws -> (added: Int, removed: Int) {
		let resource = FeedlyTagResourceID.Global.saved(for: userID)
		let remoteStarredIDs = try await collectStreamIDs(for: account, resource: resource, kind: .refreshArticleStatuses, unreadOnly: nil)

		let pendingArticleIDs = (await syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()
		let adjustedRemoteStarredIDs = remoteStarredIDs.subtracting(pendingArticleIDs)

		let localStarredIDs = await account.fetchStarredArticleIDsAsync()

		let newlyStarred = adjustedRemoteStarredIDs.subtracting(localStarredIDs)
		let toUnstar = localStarredIDs.subtracting(adjustedRemoteStarredIDs)

		await account.markAsStarredAsync(articleIDs: adjustedRemoteStarredIDs)
		await account.markAsUnstarredAsync(articleIDs: toUnstar)

		return (added: newlyStarred.count, removed: toUnstar.count)
	}

	/// IDs of articles updated on Feedly since `newerThan`.
	/// When `newerThan` is nil, returns an empty set (everything is new, nothing is updated).
	func updatedArticleIDs(for account: Account, userID: String, newerThan: Date?) async throws -> Set<String> {
		guard let newerThan else {
			Self.logger.debug("Feedly: No date provided so everything must be new (nothing is updated)")
			return Set<String>()
		}
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		let ids = try await account.logActivity(kind: .fetchArticleIDs, detail: "Updated articles", successMessage: { "\($0.count) article IDs" }, { () -> Set<String> in
			try await self.collectStreamIDs(for: account, resource: resource, kind: .fetchArticleIDs, newerThan: newerThan)
		})
		Self.logger.info("Feedly: Articles updated since last successful sync start date: \(ids.count)")
		return ids
	}

	/// Page through stream IDs for `resource`, returning the union of every page.
	/// Each page is logged as a numbered sub-activity of `kind`.
	func collectStreamIDs(for account: Account, resource: FeedlyResourceID, kind: ActivityKind, newerThan: Date? = nil, unreadOnly: Bool? = nil) async throws -> Set<String> {
		var collected = Set<String>()
		var continuation: String?
		repeat {
			let page = try await logRefreshPage(for: account, kind: kind, message: { "\($0.ids.count) article IDs" }, { try await self.caller.getStreamIDs(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly) })
			collected.formUnion(page.ids)
			continuation = page.continuation
		} while continuation != nil
		return collected
	}

	/// Fetches one page or chunk of a paginated refresh as its own numbered, timed
	/// sub-activity of `kind`, reporting the page's item count.
	private func logRefreshPage<T>(for account: Account, kind: ActivityKind, message: @escaping (T) -> String, _ fetch: () async throws -> T) async throws -> T {
		try await account.logActivity(kind: kind, detail: ActivityLog.shared.nextTaskNumberString(), successMessage: message, fetch)
	}

	/// Fetch full entries for `articleIDs` and update the account, in 1000-ID chunks.
	/// Returns the count of articles ingested.
	@discardableResult
	func downloadEntries(for account: Account, articleIDs: Set<String>) async throws -> Int {
		guard !articleIDs.isEmpty else {
			return 0
		}

		Self.logger.info("Feedly: Requesting \(articleIDs.count) articles")

		do {
			return try await account.logActivity(kind: .refreshMissingArticles) { () -> Int in
				var ingested = 0
				let chunks = Array(articleIDs).chunked(into: Self.articleDownloadChunkSize)
				for chunk in chunks {
					let entries = try await self.logRefreshPage(for: account, kind: .refreshMissingArticles, message: { "\($0.count) articles" }, { try await self.caller.getEntries(for: Set(chunk)) })
					await self.ingest(entries: entries, into: account)
					ingested += entries.count
				}
				return ingested
			}
		} catch {
			postSyncError(error, account: account, operation: "Downloading articles")
			throw error
		}
	}

	/// Pull stream contents for `resource`, optionally paginated, and update the account.
	func syncStreamContents(for account: Account, resource: FeedlyResourceID, paginated: Bool, newerThan: Date?) async throws {
		var continuation: String?
		repeat {
			let stream = try await logRefreshPage(for: account, kind: .refreshArticles, message: { "\($0.items.count) articles" }, { try await caller.getStreamContents(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: nil) })
			await ingest(entries: stream.items, into: account)
			continuation = paginated ? stream.continuation : nil
		} while continuation != nil
	}

	func ingest(entries: [FeedlyEntry], into account: Account) async {
		let parsedItems = entries.compactMap { FeedlyEntryParser(entry: $0).parsedItemRepresentation }
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { $0.feedURL }).mapValues { Set($0) }
		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}
}

// MARK: - Sync Error Posting

private extension FeedlyAccountDelegate {

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}

// MARK: - FeedlyAPICallerDelegate

extension FeedlyAccountDelegate: FeedlyAPICallerDelegate {

	/// The caller invokes this on a 401 to refresh the OAuth credentials before retrying.
	/// Storing credentials updates `self.credentials` via `Account.storeCredentials`, which in turn
	/// hands the fresh access token to the caller.
	func reauthorizeFeedlyAPICaller() async -> Bool {
		Self.logger.debug("FeedlyAccountDelegate: reauthorizeFeedlyAPICaller")

		guard let account else {
			return false
		}

		do {
			try await account.logActivity(kind: .validateCredentials, detail: "Refreshing access token") {
				guard let refreshCredentials = try account.retrieveCredentials(type: .oauthRefreshToken) else {
					Self.logger.error("Feedly: Could not find a refresh token in the keychain. Check the refresh token is added to the Keychain, remove the account and add it again.")
					throw WebserviceError.httpError(status: 403)
				}

				Self.logger.info("Feedly: Refreshing access token")
				let refreshRequest = OAuthRefreshAccessTokenRequest(refreshToken: refreshCredentials.secret, scope: nil, client: oauthAuthorizationClient)
				let response = try await caller.refreshAccessToken(refreshRequest)

				// Store the refresh token first because `Account.storeCredentials` propagates
				// the new value to this delegate; we want the access token to win that race.
				if let refreshToken = response.refreshToken {
					let newRefreshCredentials = Credentials(type: .oauthRefreshToken, username: response.id, secret: refreshToken)
					try account.storeCredentials(newRefreshCredentials)
				}

				let newAccessCredentials = Credentials(type: .oauthAccessToken, username: response.id, secret: response.accessToken)
				try account.storeCredentials(newAccessCredentials)
			}
			return true
		} catch {
			Self.logger.error("Feedly: Refresh access token failed: \(error.localizedDescription)")
			return false
		}
	}
}

// MARK: - Activity Log Messages

extension FeedlyAccountDelegate {

	/// Counts of articles whose status actually flipped during a refresh.
	struct StatusRefreshCounts {
		var unreadAdded = 0
		var unreadRemoved = 0
		var starredAdded = 0
		var starredRemoved = 0

		var totalChanged: Int {
			unreadAdded + unreadRemoved + starredAdded + starredRemoved
		}
	}

	/// Counts of folder/feed structural changes during a feed-list refresh.
	struct FeedListChanges {
		var foldersAdded = 0
		var foldersRemoved = 0
		var feedsAdded = 0
		var feedsRemoved = 0
		var feedsRenamed = 0

		var totalChanged: Int {
			foldersAdded + foldersRemoved + feedsAdded + feedsRemoved + feedsRenamed
		}
	}

	/// Aggregate counts produced by a full account refresh.
	struct RefreshAllSummary {
		var statusesSent = 0
		var feedListChanges = FeedListChanges()
		var statusRefreshCounts = StatusRefreshCounts()
		var articlesDownloaded = 0
	}

	static func sendStatusMessage(count: Int) -> String {
		if count == 0 {
			return "No statuses to send"
		}
		return "\(count) status\(count == 1 ? "" : "es") sent"
	}

	static func refreshStatusMessage(counts: StatusRefreshCounts) -> String {
		var parts = [String]()
		if counts.unreadAdded > 0 {
			parts.append("\(counts.unreadAdded) marked unread")
		}
		if counts.unreadRemoved > 0 {
			parts.append("\(counts.unreadRemoved) marked read")
		}
		if counts.starredAdded > 0 {
			parts.append("\(counts.starredAdded) starred")
		}
		if counts.starredRemoved > 0 {
			parts.append("\(counts.starredRemoved) unstarred")
		}
		if parts.isEmpty {
			return "No changes"
		}
		return parts.joined(separator: ", ")
	}

	static func feedListMessage(changes: FeedListChanges) -> String {
		var parts = [String]()
		if changes.foldersAdded > 0 {
			parts.append("\(changes.foldersAdded) folder\(changes.foldersAdded == 1 ? "" : "s") added")
		}
		if changes.foldersRemoved > 0 {
			parts.append("\(changes.foldersRemoved) folder\(changes.foldersRemoved == 1 ? "" : "s") removed")
		}
		if changes.feedsAdded > 0 {
			parts.append("\(changes.feedsAdded) feed\(changes.feedsAdded == 1 ? "" : "s") added")
		}
		if changes.feedsRemoved > 0 {
			parts.append("\(changes.feedsRemoved) feed\(changes.feedsRemoved == 1 ? "" : "s") removed")
		}
		if changes.feedsRenamed > 0 {
			parts.append("\(changes.feedsRenamed) feed\(changes.feedsRenamed == 1 ? "" : "s") renamed")
		}
		if parts.isEmpty {
			return "No changes"
		}
		return parts.joined(separator: ", ")
	}

	static func refreshAllMessage(summary: RefreshAllSummary) -> String {
		var parts = [String]()
		if summary.articlesDownloaded > 0 {
			parts.append("\(summary.articlesDownloaded) article\(summary.articlesDownloaded == 1 ? "" : "s") downloaded")
		}
		let refresh = summary.statusRefreshCounts
		if refresh.unreadAdded > 0 {
			parts.append("\(refresh.unreadAdded) marked unread")
		}
		if refresh.unreadRemoved > 0 {
			parts.append("\(refresh.unreadRemoved) marked read")
		}
		if refresh.starredAdded > 0 {
			parts.append("\(refresh.starredAdded) starred")
		}
		if refresh.starredRemoved > 0 {
			parts.append("\(refresh.starredRemoved) unstarred")
		}
		if summary.statusesSent > 0 {
			parts.append("\(summary.statusesSent) status\(summary.statusesSent == 1 ? "" : "es") sent")
		}
		let feedList = summary.feedListChanges
		if feedList.foldersAdded > 0 {
			parts.append("\(feedList.foldersAdded) folder\(feedList.foldersAdded == 1 ? "" : "s") added")
		}
		if feedList.foldersRemoved > 0 {
			parts.append("\(feedList.foldersRemoved) folder\(feedList.foldersRemoved == 1 ? "" : "s") removed")
		}
		if feedList.feedsAdded > 0 {
			parts.append("\(feedList.feedsAdded) feed\(feedList.feedsAdded == 1 ? "" : "s") added")
		}
		if feedList.feedsRemoved > 0 {
			parts.append("\(feedList.feedsRemoved) feed\(feedList.feedsRemoved == 1 ? "" : "s") removed")
		}
		if feedList.feedsRenamed > 0 {
			parts.append("\(feedList.feedsRenamed) feed\(feedList.feedsRenamed == 1 ? "" : "s") renamed")
		}
		if parts.isEmpty {
			return "No changes"
		}
		return parts.joined(separator: ", ")
	}
}
