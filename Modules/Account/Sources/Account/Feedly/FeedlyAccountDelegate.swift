//
//  FeedlyAccountDelegate.swift
//  Account
//
//  Created by Kiel Gillard on 3/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
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
	private weak var initializedAccount: Account?
	private static let logger = Feedly.logger

	private static let articleDownloadChunkSize = 1000
	private static let pendingStatusSendThreshold = 100

	init(dataFolder: String, transport: Transport?, api: FeedlyAPICaller.API) {

		if let transport {
			self.caller = FeedlyAPICaller(transport: transport, api: api)
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

			let session = URLSession(configuration: sessionConfiguration)
			self.caller = FeedlyAPICaller(transport: session, api: api)
		}

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)
		self.oauthAuthorizationClient = api.oauthAuthorizationClient

		self.caller.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	// MARK: - Account API

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll(for account: Account) async throws {
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

		do {
			try await account.logActivity(kind: .refreshAll) {
				try await sendArticleStatus(for: account)
				refreshProgress.completeTask()
				try await refreshFeedList(for: account)
				refreshProgress.completeTask()
				try await ingestStreamArticleIDs(for: account, userID: credentials.username)
				refreshProgress.completeTask()
				try await refreshArticleStatus(for: account)
				refreshProgress.completeTask()
				let updatedIDs = try await updatedArticleIDs(for: account, userID: credentials.username, newerThan: accountSettings?.lastArticleFetchStartTime)
				let missingIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
				refreshProgress.completeTask()
				try await downloadEntries(for: account, articleIDs: missingIDs.union(updatedIDs))
				refreshProgress.completeTask()
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

	func syncArticleStatus(for account: Account) async throws {
		refreshProgress.reset()
		refreshProgress.addTasks(2)
		progressInfo = ProgressInfo()
		defer {
			refreshProgress.reset()
			progressInfo = ProgressInfo()
		}

		try await sendArticleStatus(for: account)
		refreshProgress.completeTask()
		try await refreshArticleStatus(for: account)
		refreshProgress.completeTask()
	}

	func sendArticleStatus(for account: Account) async throws {
		Self.logger.info("Feedly: Sending article statuses")
		defer {
			Self.logger.info("Feedly: Finished sending article statuses")
		}

		do {
			try await account.logActivity(kind: .sendArticleStatuses) {
				guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
					return
				}

				var savedError: Error?
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
						try await caller.mark(articleIDs, as: pairing.action)
						try? await syncDatabase.deleteSelectedForProcessing(articleIDs)
					} catch {
						Self.logger.error("Feedly: Article status sync call failed: \(error.localizedDescription)")
						try? await syncDatabase.resetSelectedForProcessing(articleIDs)
						savedError = error
					}
				}

				if let savedError {
					throw savedError
				}
			}
		} catch {
			postSyncError(error, account: account, operation: "Sending article status")
			throw error
		}
	}

	/// Attempt to bring local read/starred statuses in line with the remote ones.
	/// If the user is using another Feedly client at roughly the same time as this app,
	/// this app does its part to ensure articles have a consistent status between both.
	func refreshArticleStatus(for account: Account) async throws {
		Self.logger.info("Feedly: Refreshing article statuses")

		guard let credentials else {
			return
		}

		try await account.logActivity(kind: .refreshArticleStatuses) {
			var refreshError: Error?

			do {
				try await ingestUnreadArticleIDs(for: account, userID: credentials.username)
			} catch {
				refreshError = error
				Self.logger.error("Feedly: Ingesting unread article IDs failed: \(error.localizedDescription)")
			}

			do {
				try await ingestStarredArticleIDs(for: account, userID: credentials.username)
			} catch {
				refreshError = error
				Self.logger.error("Feedly: Ingesting starred article IDs failed: \(error.localizedDescription)")
			}

			Self.logger.info("Feedly: Finished refreshing article statuses")
			if let refreshError {
				postSyncError(refreshError, account: account, operation: "Refreshing article status")
				throw refreshError
			}
		}
	}

	func importOPML(for account: Account, opmlFile: URL) async throws {
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

	func createFolder(for account: Account, name: String) async throws -> Folder {
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

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
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

	func removeFolder(for account: Account, with folder: Folder) async throws {
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
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
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

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
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

	func addFeed(account: Account, feed: Feed, container: Container) async throws {
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

	func removeFeed(account: Account, feed: Feed, container: Container) async throws {
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

	func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
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

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		Self.logger.debug("FeedlyAccountDelegate: restoreFeed")

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			_ = try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {
		Self.logger.debug("FeedlyAccountDelegate: restoreFolder")

		try await account.logActivity(kind: .restoreFolder, detail: folder.name ?? "") {
			for feed in folder.topLevelFeeds {

				folder.topLevelFeeds.remove(feed)

				do {
					try await restoreFeed(for: account, feed: feed, container: folder)
				} catch {
					Self.logger.error("Feedly: Restore folder feed error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Restoring feed")
				}
			}
			account.addFolderToTree(folder)
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		Self.logger.debug("FeedlyAccountDelegate: markArticles")
		let detail = "\(articles.count) (\(statusKey.rawValue) = \(flag))"
		let successMessage: ((queued: Int, sendTriggered: Bool)) -> String? = { info in
			let suffix = info.sendTriggered ? ", send triggered" : ""
			return "\(info.queued) status\(info.queued == 1 ? "" : "es") queued\(suffix)"
		}
		try await account.logActivity(kind: .markArticles, detail: detail, successMessage: successMessage) { () -> (queued: Int, sendTriggered: Bool) in
			let updatedArticles = try await account.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
			let syncStatuses = Set(updatedArticles.map { article in
				SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
			})

			try await syncDatabase.insertStatuses(syncStatuses)
			var sendTriggered = false
			if let count = try? await syncDatabase.selectPendingCount(), count > Self.pendingStatusSendThreshold {
				sendTriggered = true
				try await sendArticleStatus(for: account)
			}
			return (queued: syncStatuses.count, sendTriggered: sendTriggered)
		}
	}

	func accountDidInitialize(_ account: Account) {
		Self.logger.debug("FeedlyAccountDelegate: accountDidInitialize")
		initializedAccount = account
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
	}

	func accountWillBeDeleted(_ account: Account) {
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

	static func validateCredentials(transport: any Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		Self.logger.debug("FeedlyAccountDelegate: validateCredentials")
		// Feedly accounts validate via the OAuth refresh-token flow rather than this entry point.
		assertionFailure("An account instance should refresh its access token instead of calling validateCredentials.")
		return credentials
	}

	func vacuumDatabases(for account: Account) async {
		try? await account.logActivity(kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(syncDatabase.databasePath)) {
			await syncDatabase.vacuum()
		}
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity.
	func suspendNetwork() {
		Self.logger.debug("FeedlyAccountDelegate: suspendNetwork")
		caller.suspend()
	}

	/// Suspend the SQLite databases.
	func suspendDatabase() {
		Self.logger.debug("FeedlyAccountDelegate: suspendDatabase")
		syncDatabase.suspend()
	}

	/// Open the databases and resume network activity.
	func resume(account: Account) {
		Self.logger.debug("FeedlyAccountDelegate: resume")
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
		}
		syncDatabase.resume()
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

	func refreshFeedList(for account: Account) async throws {
		do {
			try await account.logActivity(kind: .refreshFeedList) {
				let collections = try await caller.getCollections()
				let pairs = mirrorCollectionsAsFolders(collections, in: account)
				syncFeedsForCollectionFolders(pairs, in: account)
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
		var continuation: String?
		repeat {
			let page = try await caller.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil)
			try await account.createStatusesIfNeededAsync(articleIDs: Set(page.ids))
			continuation = page.continuation
		} while continuation != nil
	}

	/// Mirror the remote unread set onto local statuses.
	/// Articles in the remote unread set become unread locally; the rest become read.
	/// Pending local edits are excluded so we don't temporarily clobber them.
	func ingestUnreadArticleIDs(for account: Account, userID: String) async throws {
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		let remoteUnreadIDs = try await collectStreamIDs(for: resource, unreadOnly: true)

		let pendingArticleIDs = (try await syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()
		let adjustedRemoteUnreadIDs = remoteUnreadIDs.subtracting(pendingArticleIDs)

		let localUnreadIDs = try await account.fetchUnreadArticleIDsAsync()

		try await account.markAsUnreadAsync(articleIDs: adjustedRemoteUnreadIDs)
		let toMarkRead = localUnreadIDs.subtracting(adjustedRemoteUnreadIDs)
		try await account.markAsReadAsync(articleIDs: toMarkRead)
	}

	/// Mirror the remote starred set onto local statuses.
	func ingestStarredArticleIDs(for account: Account, userID: String) async throws {
		let resource = FeedlyTagResourceID.Global.saved(for: userID)
		let remoteStarredIDs = try await collectStreamIDs(for: resource, unreadOnly: nil)

		let pendingArticleIDs = (try await syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()
		let adjustedRemoteStarredIDs = remoteStarredIDs.subtracting(pendingArticleIDs)

		let localStarredIDs = try await account.fetchStarredArticleIDsAsync()

		try await account.markAsStarredAsync(articleIDs: adjustedRemoteStarredIDs)
		let toUnstar = localStarredIDs.subtracting(adjustedRemoteStarredIDs)
		try await account.markAsUnstarredAsync(articleIDs: toUnstar)
	}

	/// IDs of articles updated on Feedly since `newerThan`.
	/// When `newerThan` is nil, returns an empty set (everything is new, nothing is updated).
	func updatedArticleIDs(for account: Account, userID: String, newerThan: Date?) async throws -> Set<String> {
		guard let newerThan else {
			Self.logger.debug("Feedly: No date provided so everything must be new (nothing is updated)")
			return Set<String>()
		}
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		let ids = try await collectStreamIDs(for: resource, newerThan: newerThan)
		Self.logger.info("Feedly: Articles updated since last successful sync start date: \(ids.count)")
		return ids
	}

	/// Page through stream IDs for `resource`, returning the union of every page.
	func collectStreamIDs(for resource: FeedlyResourceID, newerThan: Date? = nil, unreadOnly: Bool? = nil) async throws -> Set<String> {
		var collected = Set<String>()
		var continuation: String?
		repeat {
			let page = try await caller.getStreamIDs(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly)
			collected.formUnion(page.ids)
			continuation = page.continuation
		} while continuation != nil
		return collected
	}

	/// Fetch full entries for `articleIDs` and update the account, in 1000-ID chunks.
	func downloadEntries(for account: Account, articleIDs: Set<String>) async throws {
		guard !articleIDs.isEmpty else {
			return
		}

		Self.logger.info("Feedly: Requesting \(articleIDs.count) articles")

		do {
			try await account.logActivity(kind: .refreshMissingArticles) {
				let chunks = Array(articleIDs).chunked(into: Self.articleDownloadChunkSize)
				for chunk in chunks {
					let entries = try await caller.getEntries(for: Set(chunk))
					try await ingest(entries: entries, into: account)
				}
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
			let stream = try await caller.getStreamContents(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: nil)
			try await ingest(entries: stream.items, into: account)
			continuation = paginated ? stream.continuation : nil
		} while continuation != nil
	}

	func ingest(entries: [FeedlyEntry], into account: Account) async throws {
		let parsedItems = entries.compactMap { FeedlyEntryParser(entry: $0).parsedItemRepresentation }
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { $0.feedURL }).mapValues { Set($0) }
		try await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
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

		guard let account = initializedAccount else {
			return false
		}

		do {
			try await account.logActivity(kind: .validateCredentials, detail: "Refreshing access token") {
				guard let refreshCredentials = try account.retrieveCredentials(type: .oauthRefreshToken) else {
					Self.logger.error("Feedly: Could not find a refresh token in the keychain. Check the refresh token is added to the Keychain, remove the account and add it again.")
					throw TransportError.httpError(status: 403)
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
