//
//  FeedlyAccountDelegate.swift
//  Account
//
//  Created by Kiel Gillard on 3/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import AuthenticationServices
import Articles
import Parser
import Web
import SyncDatabase
import os.log
import Secrets
import Core
import CommonErrors
import Feedly

final class FeedlyAccountDelegate: AccountDelegate {

	/// Feedly has a sandbox API and a production API.
	/// This property is referred to when clients need to know which environment it should be pointing to.
	/// The value of this proptery must match any `OAuthAuthorizationClient` used.
	/// Currently this is always returning the cloud API, but we are leaving it stubbed out for now.
	static var environment: FeedlyAPICaller.API {
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

	let oauthAuthorizationClient: OAuthAuthorizationClient

	var accountMetadata: AccountMetadata?

	var refreshProgress = DownloadProgress(numberOfTasks: 0)

	private var userID: String? {
		credentials?.username
	}

	/// Set on `accountDidInitialize` for the purposes of refreshing OAuth tokens when they expire.
	/// See the implementation for `FeedlyAPICallerDelegate`.
	private weak var account: Account?
	private var refreshing = false

	internal let caller: FeedlyAPICaller

	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feedly")
	private let syncDatabase: SyncDatabase

	init(dataFolder: String, transport: Transport?, api: FeedlyAPICaller.API, secretsProvider: SecretsProvider) {
		// Many operations have their own operation queues, such as the sync all operation.
		// Making this a serial queue at this higher level of abstraction means we can ensure,
		// for example, a `FeedlyRefreshAccessTokenOperation` occurs before a `FeedlySyncAllOperation`,
		// improving our ability to debug, reason about and predict the behaviour of the code.

		if let transport = transport {
			self.caller = FeedlyAPICaller(transport: transport, api: api, secretsProvider: secretsProvider)

		} else {

			let sessionConfiguration = URLSessionConfiguration.default
			sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
			sessionConfiguration.timeoutIntervalForRequest = 60.0
			sessionConfiguration.httpShouldSetCookies = false
			sessionConfiguration.httpCookieAcceptPolicy = .never
			sessionConfiguration.httpMaximumConnectionsPerHost = 1
			sessionConfiguration.httpCookieStorage = nil
			sessionConfiguration.urlCache = nil
			sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

			let session = URLSession(configuration: sessionConfiguration)
			self.caller = FeedlyAPICaller(transport: session, api: api, secretsProvider: secretsProvider)
		}

		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databasePath)
		self.oauthAuthorizationClient = api.oauthAuthorizationClient(secretsProvider: secretsProvider)

		self.caller.delegate = self
	}

	// MARK: Account API

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {

		if refreshing {
			os_log(.debug, log: log, "Ignoring refreshAll: Feedly sync already in progress.")
			return
		}

		// TODO: update/clear refreshProgress

		refreshing = true
		defer { refreshing = false }

		let date = Date()
		defer {
			os_log(.debug, log: log, "Sync took %{public}.3f seconds", -date.timeIntervalSinceNow)
		}

		// Send any read/unread/starred article statuses to Feedly before anything else.
		try await sendArticleStatuses()

		// Get all the Collections the user has.
		let collections = try await fetchCollections()

		// Ensure a folder exists for each Collection, removing Folders without a corresponding Collection.
		guard let feedsAndFolders = mirrorCollectionsAsFolders(collections: collections) else {
			return
		}

		// Ensure feeds are created and grouped by their folders.
		createFeedsForCollectionFolders(feedsAndFolders: feedsAndFolders)

		try await fetchAndProcessAllArticleIDs()

		// Get each page of unread article ids in the global.all stream for the last 31 days (Feedly API default).
		try await fetchAndProcessUnreadArticleIDs()

		// Get each page of the article ids which have been updated since the last successful fetch start date.
		let updatedArticleIDs = try await fetchUpdatedArticleIDs()

		// Get each page of the article ids for starred articles.
		try await fetchAndProcessStarredArticleIDs()

		let missingArticleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate()

		try await downloadArticles(missingArticleIDs: missingArticleIDs, updatedArticleIDs: updatedArticleIDs)
	}

	func syncArticleStatus(for account: Account) async throws {

		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	public func sendArticleStatus(for account: Account) async throws {

		try await sendArticleStatuses()
	}

	/// Attempts to ensure local articles have the same status as they do remotely.
	/// So if the user is using another client roughly simultaneously with this app,
	/// this app does its part to ensure the articles have a consistent status between both.
	///
	/// - Parameter account: The account whose articles have a remote status.
	func refreshArticleStatus(for account: Account) async throws {

		try await fetchAndProcessUnreadArticleIDs()
		try await fetchAndProcessStarredArticleIDs()
	}

	func importOPML(for account: Account, opmlFile: URL) async throws {

		let data = try Data(contentsOf: opmlFile)

		os_log(.debug, log: log, "Begin importing OPML…")

		isOPMLImportInProgress = true
		refreshProgress.addTask()
		defer {
			isOPMLImportInProgress = false
			refreshProgress.completeTask()
		}

		do {
			try await caller.importOPML(data)
			os_log(.debug, log: self.log, "Import OPML done.")
		} catch {
			os_log(.debug, log: self.log, "Import OPML failed.")
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let collection = try await caller.createCollection(named: name)

		if let folder = account.ensureFolder(with: collection.label) {
			folder.externalID = collection.id
			return folder
		} else {
			// Is the name empty? Or one of the global resource names?
			throw FeedlyAccountDelegateError.unableToAddFolder(name)
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		guard let id = folder.externalID else {
			throw FeedlyAccountDelegateError.unableToRenameFolder(folder.nameForDisplay, name)
		}

		let nameBefore = folder.name

		do {
			let collection = try await caller.renameCollection(with: id, to: name)
			folder.name = collection.label
		} catch {
			folder.name = nameBefore
			throw error
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {

		guard let id = folder.externalID else {
			throw FeedlyAccountDelegateError.unableToRemoveFolder(folder.nameForDisplay)
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		try await caller.deleteCollection(with: id)
		account.removeFolder(folder: folder)
	}

	@discardableResult
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		// TODO: make this work

		throw FeedlyAccountDelegateError.notLoggedIn
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		let folderCollectionIDs = account.folders?.filter { $0.has(feed) }.compactMap { $0.externalID }
		guard let collectionIDs = folderCollectionIDs, let collectionID = collectionIDs.first else {
			throw FeedlyAccountDelegateError.unableToRenameFeed(feed.nameForDisplay, name)
		}

		let feedID = FeedlyFeedResourceID(id: feed.feedID)
		let editedNameBefore = feed.editedName

		// Optimistically set the name
		feed.editedName = name

		do {
			// Adding an existing feed updates it.
			// Updating feed name in one folder/collection updates it for all folders/collections.
			try await caller.addFeed(with: feedID, title: name, toCollectionWith: collectionID)
		} catch {
			feed.editedName = editedNameBefore
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		let resourceID = FeedlyFeedResourceID(id: feed.feedID)
		try await addExistingFeed(resourceID: resourceID, container: container)
	}

	func removeFeed(for account: Account, with feed: Feed, from container: any Container) async throws {

		guard let folder = container as? Folder, let collectionID = folder.externalID else {
			throw FeedlyAccountDelegateError.unableToRemoveFeed(feed.nameForDisplay)
		}

		try await caller.removeFeed(feed.feedID, fromCollectionWith: collectionID)
		folder.removeFeed(feed)
	}

	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {

		guard let sourceFolder = from as? Folder, let destinationFolder = to as? Folder else {
			throw FeedlyAccountDelegateError.addFeedChooseFolder
		}

		// Optimistically move the feed, undoing as appropriate to the failure
		sourceFolder.removeFeed(feed)
		destinationFolder.addFeed(feed)

		do {
			try await addFeed(for: account, with: feed, to: destinationFolder)
		} catch {
			destinationFolder.removeFeed(feed)
			throw FeedlyAccountDelegateError.unableToMoveFeedBetweenFolders(feed.nameForDisplay, sourceFolder.nameForDisplay, destinationFolder.nameForDisplay)
		}

		// Now that we have added the feed, remove it from the source folder
		do {
			try await removeFeed(for: account, with: feed, from: sourceFolder)
		} catch {
			sourceFolder.addFeed(feed)
			throw FeedlyAccountDelegateError.unableToMoveFeedBetweenFolders(feed.nameForDisplay, sourceFolder.nameForDisplay, destinationFolder.nameForDisplay)
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, to: container)
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
				os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
			}
		}

		account.addFolder(folder)
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		let articles = try await account.update(articles: articles, statusKey: statusKey, flag: flag)

		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		}

		try? await syncDatabase.insertStatuses(Set(syncStatuses))

		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try? await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
	}

	func accountWillBeDeleted(_ account: Account) {
		Task {
			try? await logout(account: account)
		}
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		assertionFailure("An `account` instance should refresh the access token first instead.")
		return credentials
	}

	func fetchUpdatedArticleIDs() async throws -> Set<String>? {

		guard let userID = credentials?.username else {
			return nil
		}
		guard let date = accountMetadata?.lastArticleFetchStartTime else {
			return nil // Everything is new; nothing is updated.
		}

		var articleIDs = Set<String>()
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)

		func fetchStreamIDs(_ continuation: String?) async throws {

			let streamIDs = try await caller.getStreamIDs(for: resource, continuation: continuation, newerThan: date, unreadOnly: nil)

			articleIDs.formUnion(streamIDs.ids)

			guard let continuation = streamIDs.continuation else {
				os_log(.debug, log: log, "%{public}i articles updated since last successful sync start date.", articleIDs.count)
				return
			}

			try await fetchStreamIDs(continuation)
		}

		return articleIDs
	}

	func updateAccountFeeds(parsedItems: Set<ParsedItem>) async throws {

		let feedIDsAndItems = FeedlyUtilities.parsedItemsKeyedByFeedURL(parsedItems)
		try await updateAccountFeedsWithItems(feedIDsAndItems: feedIDsAndItems)
	}

	func updateAccountFeedsWithItems(feedIDsAndItems: [String: Set<ParsedItem>]) async throws {

		guard let account else { return }

		try await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
		os_log(.debug, log: self.log, "Updated %i feeds", feedIDsAndItems.count)
	}

	func logout(account: Account) async throws {

		do {
			os_log("Requesting logout of Feedly account.")
			try await caller.logout()
			os_log("Logged out of Feedly account.")

			try account.removeCredentials(type: .oauthAccessToken)
			try account.removeCredentials(type: .oauthRefreshToken)

		} catch {
			os_log("Logout failed because %{public}@.", error as NSError)
			throw error
		}
	}

	@discardableResult
	func addFeedToCollection(feedResource: FeedlyFeedResourceID, feedName: String? = nil, collectionID: String, folder: Folder) async throws -> [([FeedlyFeed], Folder)] {

		let feedlyFeeds = try await caller.addFeed(with: feedResource, title: feedName, toCollectionWith: collectionID)

		let feedsWithCreatedFeedID = feedlyFeeds.filter { $0.id == feedResource.id }
		if feedsWithCreatedFeedID.isEmpty {
			throw AccountError.createErrorNotFound
		}

		let feedsAndFolders = [(feedlyFeeds, folder)]
		return feedsAndFolders
	}

	func downloadArticles(missingArticleIDs: Set<String>?, updatedArticleIDs: Set<String>?) async throws {

		let allArticleIDs: Set<String> = {
			var articleIDs = Set<String>()
			if let missingArticleIDs {
				articleIDs.formUnion(missingArticleIDs)
			}
			if let updatedArticleIDs {
				articleIDs.formUnion(updatedArticleIDs)
			}
			return articleIDs
		}()

		if allArticleIDs.isEmpty {
			return
		}

		os_log(.debug, log: log, "Requesting %{public}i articles.", allArticleIDs.count)

		let feedlyAPILimitBatchSize = 1000

		for articleIDs in Array(allArticleIDs).chunked(into: feedlyAPILimitBatchSize) {

			let parsedItems = try await fetchParsedItems(articleIDs: Set(articleIDs))
			try await updateAccountFeeds(parsedItems: parsedItems)
		}
	}

	func fetchParsedItems(articleIDs: Set<String>) async throws -> Set<ParsedItem> {

		do {
			let entries = try await caller.getEntries(for: articleIDs)
			return parsedItems(with: Set(entries))
		} catch {
			os_log(.debug, log: self.log, "Unable to get entries: %{public}@.", error as NSError)
			throw error
		}
	}

	func parsedItems(with entries: Set<FeedlyEntry>) -> Set<ParsedItem> {

		// TODO: convert directly from FeedlyEntry to ParsedItem without having to use FeedlyEntryParser.

		let parsedItems = Set(entries.compactMap {
			FeedlyEntryParser(entry: $0).parsedItemRepresentation
		})
		return parsedItems
	}

	func fetchCollections() async throws -> Set<FeedlyCollection> {

		os_log(.debug, log: log, "Requesting collections.")

		do {
			let collections = try await caller.getCollections()
			os_log(.debug, log: self.log, "Received collections: %{public}@", collections.map { $0.id })
			return collections
		} catch {
			os_log(.debug, log: self.log, "Unable to request collections: %{public}@.", error as NSError)
			throw error
		}
	}

	func sendArticleStatuses() async throws {

		guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
			return
		}

		let statusActionMap: [(status: SyncStatus.Key, flag: Bool, action: FeedlyMarkAction)] = [
			(.read, false, .unread),
			(.read, true, .read),
			(.starred, true, .saved),
			(.starred, false, .unsaved)
		]

		for statusAction in statusActionMap {

			let statuses = syncStatuses.filter {
				$0.key == statusAction.status && $0.flag == statusAction.flag
			}
			guard !statuses.isEmpty else {
				continue
			}

			let articleIDs = Set(statuses.map { $0.articleID })

			do {
				try await caller.mark(articleIDs, as: statusAction.action)
				try? await syncDatabase.deleteSelectedForProcessing(articleIDs)
			} catch {
				try? await syncDatabase.resetSelectedForProcessing(articleIDs)
				throw error
			}
		}

		os_log(.debug, log: self.log, "Done sending article statuses.")
	}

	func searchForFeed(url: String) async throws -> FeedlyFeedsSearchResponse {

		try await caller.getFeeds(for: url, count: 1, localeIdentifier: Locale.current.identifier)
	}

	func fetchStreamContents(resourceID: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool? = nil) async throws -> Set<ParsedItem> {

		do {
			let stream = try await caller.getStreamContents(for: resourceID, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly)
			return parsedItems(with: Set(stream.items))
		} catch {
			os_log(.debug, log: self.log, "Unable to get stream contents: %{public}@.", error as NSError)
			throw error
		}
	}

	func fetchRemoteArticleIDs(resource: FeedlyResourceID, unreadOnly: Bool? = nil) async throws -> Set<String> {

		var remoteArticleIDs = Set<String>()

		func fetchIDs(_ continuation: String? = nil) async throws {

			let streamIDs = try await caller.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: unreadOnly)
			remoteArticleIDs.formUnion(streamIDs.ids)

			guard let continuation = streamIDs.continuation else { // finished fetching article IDs?
				return
			}

			try await fetchIDs(continuation)
		}

		try await fetchIDs()
		return remoteArticleIDs
	}

	func fetchRemoteUnreadArticleIDs() async throws -> Set<String> {

		guard let userID else { return Set<String>() }

		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		return try await fetchRemoteArticleIDs(resource: resource, unreadOnly: true)
	}

	func fetchRemoteStarredArticleIDs() async throws -> Set<String> {

		guard let userID else { return Set<String>() }

		let resource = FeedlyTagResourceID.Global.saved(for: userID)
		return try await fetchRemoteArticleIDs(resource: resource)
	}

	func processStarredArticleIDs(remoteArticleIDs: Set<String>) async throws {

		guard let account else { return }

		var remoteArticleIDs = remoteArticleIDs

		func removeEntryIDsWithPendingStatus() async throws {

			if let pendingArticleIDs = try await syncDatabase.selectPendingStarredStatusArticleIDs() {
				remoteArticleIDs.subtract(pendingArticleIDs)
			}
		}

		func process() async throws {

			let localStarredArticleIDs = (try await account.fetchStarredArticleIDs()) ?? Set<String>()

			var markAsStarredError: Error?
			var markAsUnstarredError: Error?

			let remoteStarredArticleIDs = remoteArticleIDs
			do {
				try await account.markAsStarred(remoteStarredArticleIDs)
			} catch {
				markAsStarredError = error
			}

			let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
			do {
				try await account.markAsUnstarred(deltaUnstarredArticleIDs)
			} catch {
				markAsUnstarredError = error
			}

			if let markingError = markAsStarredError ?? markAsUnstarredError {
				throw markingError
			}
		}

		try await removeEntryIDsWithPendingStatus()
		try await process()
	}

	func fetchAndProcessStarredArticleIDs() async throws {

		let remoteArticleIDs = try await fetchRemoteStarredArticleIDs()
		try await processStarredArticleIDs(remoteArticleIDs: remoteArticleIDs)
	}

	func processUnreadArticleIDs(remoteArticleIDs: Set<String>) async throws {

		guard let account else { return }

		var remoteArticleIDs = remoteArticleIDs

		func removeEntryIDsWithPendingStatus() async throws {

			if let pendingArticleIDs = try await syncDatabase.selectPendingReadStatusArticleIDs() {
				remoteArticleIDs.subtract(pendingArticleIDs)
			}
		}

		func process() async throws {

			let localUnreadArticleIDs = try await account.fetchUnreadArticleIDs() ?? Set<String>()

			var markAsUnreadError: Error?
			var markAsReadError: Error?

			let remoteUnreadArticleIDs = remoteArticleIDs

			do {
				try await account.markAsUnread(remoteUnreadArticleIDs)
			} catch {
				markAsUnreadError = error
			}

			let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
			do {
				try await account.markAsRead(articleIDsToMarkRead)
			} catch {
				markAsReadError = error
			}

			if let markingError = markAsReadError ?? markAsUnreadError {
				throw markingError
			}
		}

		try await removeEntryIDsWithPendingStatus()
		try await process()
	}

	func fetchAndProcessUnreadArticleIDs() async throws {

		let remoteArticleIDs = try await fetchRemoteUnreadArticleIDs()
		try await processUnreadArticleIDs(remoteArticleIDs: remoteArticleIDs)
	}

	func fetchAllArticleIDs() async throws -> Set<String> {

		guard let userID else { return Set<String>() }

		var allArticleIDs = Set<String>()
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)

		func fetchStreamIDs(_ continuation: String?) async throws {

			let streamIDs = try await caller.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil)

			allArticleIDs.formUnion(streamIDs.ids)

			guard let continuation = streamIDs.continuation else {
				os_log(.debug, log: self.log, "Reached end of stream for %@", resource.id)
				return
			}

			try await fetchStreamIDs(continuation)
		}

		return allArticleIDs
	}

	func fetchAndProcessAllArticleIDs() async throws {

		guard let account else { return }

		let allArticleIDs = try await fetchAllArticleIDs()
		try await account.createStatusesIfNeeded(articleIDs: allArticleIDs)
	}

	func syncStreamContents(feedResourceID: FeedlyFeedResourceID) async throws {

		let parsedItems = try await fetchStreamContents(resourceID: feedResourceID, newerThan: nil)
		try await updateAccountFeeds(parsedItems: parsedItems)
	}

	@MainActor struct FeedlyFeedContainerValidator {
		var container: Container

		func getValidContainer() throws -> (Folder, String) {
			guard let folder = container as? Folder else {
				throw FeedlyAccountDelegateError.addFeedChooseFolder
			}

			guard let collectionID = folder.externalID else {
				throw FeedlyAccountDelegateError.addFeedInvalidFolder(folder.nameForDisplay)
			}

			return (folder, collectionID)
		}
	}

	func addNewFeed(url: String, feedName: String?, container: Container) async throws {

		let validator = FeedlyFeedContainerValidator(container: container)
		let (folder, collectionID) = try validator.getValidContainer()

		let searchResponse = try await searchForFeed(url: url)
		guard let firstFeed = searchResponse.results.first else {
			throw AccountError.createErrorNotFound
		}
		let feedResourceID = FeedlyFeedResourceID(id: firstFeed.feedID)

		try await addFeedToCollection(feedResource: feedResourceID, feedName: feedName, collectionID: collectionID, folder: folder)
		
		// TODO: FeedlyCreateFeedsForCollectionFoldersOperation replacement
//		let createFeeds = TODO

		//try await fetchAndProcessUnreadArticleIDs() // TODO
		try await syncStreamContents(feedResourceID: feedResourceID)
	}

	func addExistingFeed(resourceID: FeedlyFeedResourceID, container: Container, customFeedName: String? = nil) async throws {

		let validator = FeedlyFeedContainerValidator(container: container)
		let (folder, collectionID) = try validator.getValidContainer()

		try await addFeedToCollection(feedResource: resourceID, feedName: customFeedName, collectionID: collectionID, folder: folder)
	}

	func mirrorCollectionsAsFolders(collections: Set<FeedlyCollection>) -> [([FeedlyFeed], Folder)]? {

		guard let account else { return nil }

		let localFolders = account.folders ?? Set()

		let feedsAndFolders: [([FeedlyFeed], Folder)] = collections.compactMap { collection -> ([FeedlyFeed], Folder)? in
			let parser = FeedlyCollectionParser(collection: collection)
			guard let folder = account.ensureFolder(with: parser.folderName) else {
				assertionFailure("Why wasn't a folder created?")
				return nil
			}
			folder.externalID = parser.externalID
			return (collection.feeds, folder)
		}

		os_log(.debug, log: log, "Ensured %i folders for %i collections.", feedsAndFolders.count, collections.count)

		// Remove folders without a corresponding collection
		let collectionFolders = Set(feedsAndFolders.map { $0.1 })
		let foldersWithoutCollections = localFolders.subtracting(collectionFolders)

		if !foldersWithoutCollections.isEmpty {
			for unmatched in foldersWithoutCollections {
				account.removeFolder(folder: unmatched)
			}

			os_log(.debug, log: log, "Removed %i folders: %@", foldersWithoutCollections.count, foldersWithoutCollections.map { $0.externalID ?? $0.nameForDisplay })
		}

		return feedsAndFolders
	}

	func createFeedsForCollectionFolders(feedsAndFolders: [([FeedlyFeed], Folder)]) {

		guard let account else { return }

		let pairs = feedsAndFolders

		let feedsBefore = Set(pairs
			.map { $0.1 }
			.flatMap { $0.topLevelFeeds })

		// Remove feeds in a folder which are not in the corresponding collection.
		for (collectionFeeds, folder) in pairs {
			let feedsInFolder = folder.topLevelFeeds
			let feedsInCollection = Set(collectionFeeds.map { $0.id })
			let feedsToRemove = feedsInFolder.filter { !feedsInCollection.contains($0.feedID) }
			if !feedsToRemove.isEmpty {
				folder.removeFeeds(feedsToRemove)
//				os_log(.debug, log: log, "\"%@\" - removed: %@", collection.label, feedsToRemove.map { $0.feedID }, feedsInCollection)
			}

		}

		// Pair each Feed with its Folder.
		var feedsAdded = Set<Feed>()

		let feedsAndFolders = pairs
			.map({ (collectionFeeds, folder) -> [(FeedlyFeed, Folder)] in
				return collectionFeeds.map { feed -> (FeedlyFeed, Folder) in
					return (feed, folder) // pairs a folder for every feed in parallel
				}
			})
			.flatMap { $0 }
			.compactMap { (collectionFeed, folder) -> (Feed, Folder) in

				// find an existing feed previously added to the account
				if let feed = account.existingFeed(withFeedID: collectionFeed.id) {

					// If the feed was renamed on Feedly, ensure we ingest the new name.
					if feed.nameForDisplay != collectionFeed.title {
						feed.name = collectionFeed.title

						// Let the rest of the app (e.g.: the sidebar) know the feed name changed
						// `editedName` would post this if its value is changing.
						// Setting the `name` property has no side effects like this.
						if feed.editedName != nil {
							feed.editedName = nil
						} else {
							feed.postDisplayNameDidChangeNotification()
						}
					}
					return (feed, folder)
				} else {
					// find an existing feed we created below in an earlier value
					for feed in feedsAdded where feed.feedID == collectionFeed.id {
						return (feed, folder)
					}
				}

				// no existing feed, create a new one
				let parser = FeedlyFeedParser(feed: collectionFeed)
				let feed = account.createFeed(with: parser.title,
												 url: parser.url,
												 feedID: parser.feedID,
												 homePageURL: parser.homePageURL)

				// So the same feed isn't created more than once.
				feedsAdded.insert(feed)

				return (feed, folder)
			}

		os_log(.debug, log: log, "Processing %i feeds.", feedsAndFolders.count)
		for (feed, folder) in feedsAndFolders {
			if !folder.has(feed) {
				folder.addFeed(feed)
			}
		}

		// Remove feeds without folders/collections.
		let feedsAfter = Set(feedsAndFolders.map { $0.0 })
		let feedsWithoutCollections = feedsBefore.subtracting(feedsAfter)
		account.removeFeeds(feedsWithoutCollections)

		if !feedsWithoutCollections.isEmpty {
			os_log(.debug, log: log, "Removed %i feeds", feedsWithoutCollections.count)
		}
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		MainActor.assumeIsolated {
			caller.suspend()
			// TODO: cancel tasks
		//	operationQueue.cancelAllOperations()
		}
	}
	
	/// Suspend the SQLite databases
	func suspendDatabase() {
		Task {
			await syncDatabase.suspend()
		}
	}
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		Task {
			await syncDatabase.resume()
			caller.resume()
		}
	}
}

extension FeedlyAccountDelegate: FeedlyAPICallerDelegate {
	
	func reauthorizeFeedlyAPICaller(_ caller: FeedlyAPICaller) async -> Bool {

		guard let account else {
			return false
		}

		do {
			try await refreshAccessToken(account: account)
			return true
		} catch {
			return false
		}
	}

	private func refreshAccessToken(account: Account) async throws {

		guard let credentials = try account.retrieveCredentials(type: .oauthRefreshToken) else {
			os_log(.debug, log: log, "Could not find a refresh token in the keychain. Check the refresh token is added to the Keychain, remove the account and add it again.")
			throw TransportError.httpError(status: 403)
		}

		os_log(.debug, log: log, "Refreshing access token.")
		let grant = try await caller.refreshAccessToken(with: credentials.secret, client: oauthAuthorizationClient)

		os_log(.debug, log: log, "Storing refresh token.")
		if let refreshToken = grant.refreshToken {
			try account.storeCredentials(refreshToken)
		}

		os_log(.debug, log: log, "Storing access token.")
		try account.storeCredentials(grant.accessToken)
	}
}

public protocol FeedlyOAuthAccountAuthorizationOperationDelegate: AnyObject {

	@MainActor func oauthAccountAuthorizationOperation(_ operation: FeedlyOAuthAccountAuthorizationOperation, didCreate account: Account)
	@MainActor func oauthAccountAuthorizationOperation(_ operation: FeedlyOAuthAccountAuthorizationOperation, didFailWith error: Error)
}

public enum FeedlyOAuthAccountAuthorizationOperationError: LocalizedError {
	case duplicateAccount

	public var errorDescription: String? {
		return NSLocalizedString("There is already a Feedly account with that username created.", comment: "Duplicate Error")
	}
}
@MainActor @objc public final class FeedlyOAuthAccountAuthorizationOperation: NSObject {

	public var isCanceled: Bool = false {
		didSet {
			if isCanceled {
				cancel()
			}
		}
	}

	public var completionBlock: ((FeedlyOAuthAccountAuthorizationOperation) -> Void)?

	public weak var presentationAnchor: ASPresentationAnchor?
	public weak var delegate: FeedlyOAuthAccountAuthorizationOperationDelegate?

	private let oauthClient: OAuthAuthorizationClient
	private var session: ASWebAuthenticationSession?
	private let secretsProvider: SecretsProvider

	public init(secretsProvider: SecretsProvider) {
		self.secretsProvider = secretsProvider
		self.oauthClient = FeedlyAPICaller.API.cloud.oauthAuthorizationClient(secretsProvider: secretsProvider)
	}

	public func run() {
		assert(presentationAnchor != nil, "\(self) outlived presentation anchor.")

		let request = FeedlyAPICaller.oauthAuthorizationCodeGrantRequest(secretsProvider: secretsProvider)

		guard let url = request.url else {
			return DispatchQueue.main.async {
				self.didEndAuthentication(url: nil, error: URLError(.badURL))
			}
		}

		guard let redirectURI = URL(string: oauthClient.redirectURI), let scheme = redirectURI.scheme else {
			assertionFailure("Could not get callback URL scheme from \(oauthClient.redirectURI)")
			return DispatchQueue.main.async {
				self.didEndAuthentication(url: nil, error: URLError(.badURL))
			}
		}

		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { url, error in
			DispatchQueue.main.async { [weak self] in
				self?.didEndAuthentication(url: url, error: error)
			}
		}

		session.presentationContextProvider = self

		guard session.start() else {

			/// Documentation does not say on why `ASWebAuthenticationSession.start` or `canStart` might return false.
			/// Perhaps it has something to do with an inter-process communication failure? No browsers installed? No browsers that support web authentication?
			struct UnableToStartASWebAuthenticationSessionError: LocalizedError {
				let errorDescription: String? = NSLocalizedString("Unable to start a web authentication session with the default web browser.",
																  comment: "OAuth - error description - unable to authorize because ASWebAuthenticationSession did not start.")
				let recoverySuggestion: String? = NSLocalizedString("Check your default web browser in System Preferences or change it to Safari and try again.",
																	comment: "OAuth - recovery suggestion - ensure browser selected supports web authentication.")
			}

			didFinish(UnableToStartASWebAuthenticationSessionError())

			return
		}

		self.session = session
	}

	public func cancel() {
		session?.cancel()
	}

	private func didEndAuthentication(url: URL?, error: Error?) {

		Task {
			guard !isCanceled else {
				didFinish()
				return
			}

			do {
				guard let url = url else {
					if let error {
						throw error
					}
					throw URLError(.badURL)
				}

				let response = try OAuthAuthorizationResponse(url: url, client: self.oauthClient)

				let tokenResponse = try await FeedlyAPICaller.requestOAuthAccessToken(with: response, transport: URLSession.webserviceTransport(), secretsProvider: secretsProvider)
				saveAccount(for: tokenResponse)

			} catch is ASWebAuthenticationSessionError {
				didFinish() // Primarily, cancellation.

			} catch {
				didFinish(error)
			}
		}
	}

	private func saveAccount(for grant: OAuthAuthorizationGrant) {
		guard !AccountManager.shared.duplicateServiceAccount(type: .feedly, username: grant.accessToken.username) else {
			didFinish(FeedlyOAuthAccountAuthorizationOperationError.duplicateAccount)
			return
		}

		let account = AccountManager.shared.createAccount(type: .feedly)
		do {

			// Store the refresh token first because it sends this token to the account delegate.
			if let token = grant.refreshToken {
				try account.storeCredentials(token)
			}

			// Now store the access token because we want the account delegate to use it.
			try account.storeCredentials(grant.accessToken)

			delegate?.oauthAccountAuthorizationOperation(self, didCreate: account)

			didFinish()
		} catch {
			didFinish(error)
		}
	}

	// MARK: Managing Operation State

	private func didFinish() {
		assert(Thread.isMainThread)
//		operationDelegate?.operationDidComplete(self)
	}

	private func didFinish(_ error: Error) {
		assert(Thread.isMainThread)
		delegate?.oauthAccountAuthorizationOperation(self, didFailWith: error)
		didFinish()
	}
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension FeedlyOAuthAccountAuthorizationOperation: ASWebAuthenticationPresentationContextProviding {

	nonisolated public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {

		MainActor.assumeIsolated {
			guard let anchor = presentationAnchor else {
				fatalError("\(self) has outlived presentation anchor.")
			}
			return anchor
		}
	}
}
