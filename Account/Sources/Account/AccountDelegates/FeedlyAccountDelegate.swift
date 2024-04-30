//
//  FeedlyAccountDelegate.swift
//  Account
//
//  Created by Kiel Gillard on 3/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

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

	private weak var currentSyncAllOperation: MainThreadOperation?
	private let operationQueue = MainThreadOperationQueue()

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

			if let userAgentHeaders = UserAgent.headers() {
				sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
			}

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

		// To replace FeedlySyncAllOperation
		
		if refreshing {
			os_log(.debug, log: log, "Ignoring refreshAll: Feedly sync already in progress.")
			return

		}

		// TODO: update/clear refreshProgress

		refreshing = true
		defer { refreshing = false }

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

	private func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		assert(Thread.isMainThread)

		guard currentSyncAllOperation == nil else {
			os_log(.debug, log: log, "Ignoring refreshAll: Feedly sync already in progress.")
			completion(.success(()))
			return
		}

		guard let credentials = credentials else {
			os_log(.debug, log: log, "Ignoring refreshAll: Feedly account has no credentials.")
			completion(.failure(FeedlyAccountDelegateError.notLoggedIn))
			return
		}

		let log = self.log

		let syncAllOperation = FeedlySyncAllOperation(account: account, feedlyUserID: credentials.username, caller: caller, database: syncDatabase, lastSuccessfulFetchStartDate: accountMetadata?.lastArticleFetchStartTime, downloadProgress: refreshProgress, log: log)

		syncAllOperation.downloadProgress = refreshProgress

		let date = Date()
		syncAllOperation.syncCompletionHandler = { [weak self] result in
			if case .success = result {
				self?.accountMetadata?.lastArticleFetchStartTime = date
				self?.accountMetadata?.lastArticleFetchEndTime = Date()
			}

			os_log(.debug, log: log, "Sync took %{public}.3f seconds", -date.timeIntervalSinceNow)
			completion(result)
		}

		currentSyncAllOperation = syncAllOperation

		operationQueue.add(syncAllOperation)
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				switch result {
				case .success:
					self.refreshArticleStatus(for: account) { result in
						switch result {
						case .success:
							continuation.resume()
						case .failure(let error):
							continuation.resume(throwing: error)
						}
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	public func sendArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.sendArticleStatus(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	@MainActor private func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		// Ensure remote articles have the same status as they do locally.
		let send = FeedlySendArticleStatusesOperation(database: syncDatabase, service: caller, log: log)
		send.completionBlock = { operation in
			// TODO: not call with success if operation was canceled? Not sure.
			DispatchQueue.main.async {
				completion(.success(()))
			}
		}
		operationQueue.add(send)
	}

	func refreshArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.refreshArticleStatus(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Attempts to ensure local articles have the same status as they do remotely.
	/// So if the user is using another client roughly simultaneously with this app,
	/// this app does its part to ensure the articles have a consistent status between both.
	///
	/// - Parameter account: The account whose articles have a remote status.
	/// - Parameter completion: Call on the main queue.
	private func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard let credentials = credentials else {
			return completion(.success(()))
		}

		let group = DispatchGroup()

		let ingestUnread = FeedlyIngestUnreadArticleIDsOperation(account: account, userID: credentials.username, service: caller, database: syncDatabase, newerThan: nil, log: log)

		group.enter()
		ingestUnread.completionBlock = { _ in
			group.leave()

		}

		let ingestStarred = FeedlyIngestStarredArticleIDsOperation(account: account, userID: credentials.username, service: caller, database: syncDatabase, newerThan: nil, log: log)

		group.enter()
		ingestStarred.completionBlock = { _ in
			group.leave()
		}

		group.notify(queue: .main) {
			completion(.success(()))
		}

		operationQueue.addOperations([ingestUnread, ingestStarred])
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

	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		try await withCheckedThrowingContinuation { continuation in
			self.createFeed(for: account, url: url, name: name, container: container, validateFeed: validateFeed) { result in
				switch result {
				case .success(let feed):
					continuation.resume(returning: feed)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {

		do {
			guard let credentials = credentials else {
				throw FeedlyAccountDelegateError.notLoggedIn
			}

			let addNewFeed = try FeedlyAddNewFeedOperation(account: account,
														   credentials: credentials,
														   url: url,
														   feedName: name,
														   searchService: caller,
														   addToCollectionService: caller,
														   syncUnreadIDsService: caller,
														   getStreamContentsService: caller,
														   database: syncDatabase,
														   container: container,
														   progress: refreshProgress,
														   log: log)

			addNewFeed.addCompletionHandler = { result in
				completion(result)
			}

			operationQueue.add(addNewFeed)

		} catch {
			DispatchQueue.main.async {
				completion(.failure(error))
			}
		}
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

		try await withCheckedThrowingContinuation { continuation in

			self.addFeed(for: account, with: feed, to: container) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {

		do {
			guard let credentials = credentials else {
				throw FeedlyAccountDelegateError.notLoggedIn
			}

			let resource = FeedlyFeedResourceID(id: feed.feedID)
			let addExistingFeed = try FeedlyAddExistingFeedOperation(account: account,
																	 credentials: credentials,
																	 resource: resource,
																	 service: caller,
																	 container: container,
																	 progress: refreshProgress,
																	 log: log,
																	 customFeedName: feed.editedName)


			addExistingFeed.addCompletionHandler = { result in
				completion(result)
			}

			operationQueue.add(addExistingFeed)

		} catch {
			DispatchQueue.main.async {
				completion(.failure(error))
			}
		}
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

		try await withCheckedThrowingContinuation { continuation in

			self.restoreFeed(for: account, feed: feed, container: container) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {

		if let existingFeed = account.existingFeed(withURL: feed.url) {

			Task { @MainActor in
				do {
					try await account.addFeed(existingFeed, to: container)
					completion(.success(()))
				} catch {
					completion(.failure(error))
				}
			}
		} else {
			createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true) { result in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.restoreFolder(for: account, folder: folder) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		let group = DispatchGroup()

		for feed in folder.topLevelFeeds {

			folder.topLevelFeeds.remove(feed)

			group.enter()
			restoreFeed(for: account, feed: feed, container: folder) { result in
				group.leave()
				switch result {
				case .success:
					break
				case .failure(let error):
					os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
				}
			}

		}

		group.notify(queue: .main) {
			account.addFolder(folder)
			completion(.success(()))
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.markArticles(for: account, articles: articles, statusKey: statusKey, flag: flag) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {

		Task { @MainActor in

			do {

				let articles = try await account.update(articles: articles, statusKey: statusKey, flag: flag)

				let syncStatuses = articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				}

				try? await self.syncDatabase.insertStatuses(syncStatuses)

				if let count = try? await self.syncDatabase.selectPendingCount(), count > 100 {
					self.sendArticleStatus(for: account) { _ in }
				}
				completion(.success(()))

			} catch {
				completion(.failure(error))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
	}

	@MainActor func accountWillBeDeleted(_ account: Account) {
		let logout = FeedlyLogoutOperation(service: caller, log: log)
		// Dispatch on the shared queue because the lifetime of the account delegate is uncertain.
		MainThreadOperationQueue.shared.add(logout)
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		assertionFailure("An `account` instance should refresh the access token first instead.")
		return credentials
	}

	func fetchUpdatedArticleIDs() async throws -> Set<String>? {

		// To replace FeedlyGetUpdatedArticleIDsOperation

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

		let feedIDsAndItems = parsedItemsKeyedByFeedURL(parsedItems)
		try await updateAccountFeedsWithItems(feedIDsAndItems: feedIDsAndItems)
	}

	func updateAccountFeedsWithItems(feedIDsAndItems: [String: Set<ParsedItem>]) async throws {

		// To replace FeedlyUpdateAccountFeedsWithItemsOperation

		guard let account else { return }

		try await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
		os_log(.debug, log: self.log, "Updated %i feeds", feedIDsAndItems.count)
	}

	func logout(account: Account) async throws {

		// To replace FeedlyLogoutOperation

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

		// To replace FeedlyAddFeedToCollectionOperation

		let feedlyFeeds = try await caller.addFeed(with: feedResource, title: feedName, toCollectionWith: collectionID)

		let feedsWithCreatedFeedID = feedlyFeeds.filter { $0.id == feedResource.id }
		if feedsWithCreatedFeedID.isEmpty {
			throw AccountError.createErrorNotFound
		}

		let feedsAndFolders = [(feedlyFeeds, folder)]
		return feedsAndFolders
	}

	func parsedItemsKeyedByFeedURL(_ parsedItems: Set<ParsedItem>) -> [String: Set<ParsedItem>] {

		// To replace FeedlyOrganiseParsedItemsByFeedOperation

		var d = [String: Set<ParsedItem>]()

		for parsedItem in parsedItems {
			let key = parsedItem.feedURL
			let value: Set<ParsedItem> = {
				if var items = d[key] {
					items.insert(parsedItem)
					return items
				} else {
					return [parsedItem]
				}
			}()
			d[key] = value
		}

		return d
	}

	func downloadArticles(missingArticleIDs: Set<String>?, updatedArticleIDs: Set<String>?) async throws {

		// To replace FeedlyDownloadArticlesOperation

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

		// To replace FeedlyGetEntriesOperation

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

		// To replace FeedlyGetCollectionsOperation

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

		// To replace FeedlySendArticleStatusesOperation

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
				try? await syncDatabase.deleteSelectedForProcessing(Array(articleIDs))
			} catch {
				try? await syncDatabase.resetSelectedForProcessing(Array(articleIDs))
				throw error
			}
		}

		os_log(.debug, log: self.log, "Done sending article statuses.")
	}

	func searchForFeed(url: String) async throws -> FeedlyFeedsSearchResponse {

		// To replace FeedlySearchOperation

		try await caller.getFeeds(for: url, count: 1, localeIdentifier: Locale.current.identifier)
	}

	func fetchStreamContents(resourceID: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool? = nil) async throws -> Set<ParsedItem> {

		// To replace FeedlyGetStreamContentsOperation

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

		// To replace FeedlyIngestStarredArticleIDsOperation

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

		// To replace FeedlyIngestUnreadArticleIDsOperation

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

		// To replace FeedlyIngestStreamArticleIDsOperation

		guard let account else { return }

		let allArticleIDs = try await fetchAllArticleIDs()
		try await account.createStatusesIfNeeded(articleIDs: allArticleIDs)
	}

	func syncStreamContents(feedResourceID: FeedlyFeedResourceID) async throws {

		// To replace FeedlySyncStreamContentsOperation

		let parsedItems = try await fetchStreamContents(resourceID: feedResourceID, newerThan: nil)
		try await updateAccountFeeds(parsedItems: parsedItems)
	}

	func addNewFeed(url: String, feedName: String?, container: Container) async throws {

		// To replace FeedlyAddNewFeedOperation

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

		// To replace FeedlyAddExistingFeedOperation

		let validator = FeedlyFeedContainerValidator(container: container)
		let (folder, collectionID) = try validator.getValidContainer()

		try await addFeedToCollection(feedResource: resourceID, feedName: customFeedName, collectionID: collectionID, folder: folder)
	}

	func mirrorCollectionsAsFolders(collections: Set<FeedlyCollection>) -> [([FeedlyFeed], Folder)]? {

		// To replace FeedlyMirrorCollectionsAsFoldersOperation

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

		// To replace FeedlyCreateFeedsForCollectionFoldersOperation

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
			operationQueue.cancelAllOperations()
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
	
	@MainActor func reauthorizeFeedlyAPICaller(_ caller: FeedlyAPICaller) async -> Bool {

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
		let grant = try await refreshAccessToken(with: credentials.secret, client: oauthAuthorizationClient)

		os_log(.debug, log: log, "Storing refresh token.")
		if let refreshToken = grant.refreshToken {
			try account.storeCredentials(refreshToken)
		}

		os_log(.debug, log: log, "Storing access token.")
		try account.storeCredentials(grant.accessToken)
	}
}
