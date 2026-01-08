//
//  FeedlyAccountDelegate.swift
//  Account
//
//  Created by Kiel Gillard on 3/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

@MainActor final class FeedlyAccountDelegate: AccountDelegate {
	/// Feedly has a sandbox API and a production API.
	/// This property is referred to when clients need to know which environment it should be pointing to.
	/// The value of this property must match any `OAuthAuthorizationClient` used.
	/// Currently this is always returning the cloud API, but we are leaving it stubbed out for now.
	nonisolated static var environment: FeedlyAPICaller.API {
		return .cloud
	}

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
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

	/// Set on `accountDidInitialize` for the purposes of refreshing OAuth tokens when they expire.
	/// See the implementation for `FeedlyAPICallerDelegate`.
	private weak var initializedAccount: Account?

	let caller: FeedlyAPICaller

	nonisolated private static let logger = Feedly.logger
	private let syncDatabase: SyncDatabase

	private weak var currentSyncAllOperation: MainThreadOperation?
	private let operationQueue = MainThreadOperationQueue()

	init(dataFolder: String, transport: Transport?, api: FeedlyAPICaller.API) {
		// Many operations have their own operation queues, such as the sync all operation.
		// Making this a serial queue at this higher level of abstraction means we can ensure,
		// for example, a `FeedlyRefreshAccessTokenOperation` occurs before a `FeedlySyncAllOperation`,
		// improving our ability to debug, reason about and predict the behaviour of the code.

		if let transport = transport {
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

		NotificationCenter.default.addObserver(self, selector: #selector(syncProgressDidChange(_:)), name: .progressInfoDidChange, object: operationQueue)
	}

	// MARK: Account API

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshAll(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		assert(Thread.isMainThread)

		guard !Platform.isRunningUnitTests else {
			Self.logger.debug("Feedly: Ignoring refreshAll: running unit tests")
			completion(.success(()))
			return
		}
		guard currentSyncAllOperation == nil else {
			Self.logger.debug("Feedly: Ignoring refreshAll: sync already in progress")
			completion(.success(()))
			return
		}

		guard let credentials = credentials else {
			Self.logger.info("Feedly: Ignoring refreshAll: account has no credentials")
			completion(.failure(FeedlyAccountDelegateError.notLoggedIn))
			return
		}

		progressInfo = ProgressInfo()

		let syncAllOperation = FeedlySyncAllOperation(account: account, feedlyUserId: credentials.username, caller: caller, database: syncDatabase, lastSuccessfulFetchStartDate: accountMetadata?.lastArticleFetchStartTime, operationQueue: operationQueue)

		let date = Date()
		syncAllOperation.syncCompletionHandler = { [weak self] result in
			if case .success = result {
				self?.accountMetadata?.lastArticleFetchStartTime = date
				self?.accountMetadata?.lastArticleFetchEndTime = Date()
			}

			Self.logger.debug("Feedly: Sync took \(-date.timeIntervalSinceNow, privacy: .public) seconds")
			completion(result)
			self?.operationQueue.isTrackingProgress = false
			self?.progressInfo = ProgressInfo()
		}

		currentSyncAllOperation = syncAllOperation
		operationQueue.isTrackingProgress = true
		operationQueue.suspend()
		operationQueue.add(syncAllOperation)
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		// Ensure remote articles have the same status as they do locally.
		let send = FeedlySendArticleStatusesOperation(database: syncDatabase, service: caller)
		send.completionBlock = { operation in
			// TODO: not call with success if operation was canceled? Not sure.
			DispatchQueue.main.async {
				completion(.success(()))
			}
		}
		operationQueue.add(send)
	}

	/// Attempts to ensure local articles have the same status as they do remotely.
	/// So if the user is using another client roughly simultaneously with this app,
	/// this app does its part to ensure the articles have a consistent status between both.
	///
	/// - Parameter account: The account whose articles have a remote status.
	@MainActor func refreshArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard let credentials = credentials else {
			return completion(.success(()))
		}

		let group = DispatchGroup()

		let ingestUnread = FeedlyIngestUnreadArticleIdsOperation(account: account, userId: credentials.username, service: caller, database: syncDatabase, newerThan: nil)

		group.enter()
		ingestUnread.completionBlock = { _ in
			group.leave()

		}

		let ingestStarred = FeedlyIngestStarredArticleIdsOperation(account: account, userId: credentials.username, service: caller, database: syncDatabase, newerThan: nil)

		group.enter()
		ingestStarred.completionBlock = { _ in
			group.leave()
		}

		group.notify(queue: .main) {
			completion(.success(()))
		}

		operationQueue.add([ingestUnread, ingestStarred])
	}


	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
		try await withCheckedThrowingContinuation { continuation in
			importOPML(for: account, opmlFile: opmlFile) { result in
				continuation.resume(with: result)
			}
		}
	}

	func importOPML(for account: Account, opmlFile: URL, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		let data: Data

		do {
			data = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}

		Self.logger.info("Feedly: Begin importing OPML")
		isOPMLImportInProgress = true

		caller.importOpml(data) { result in
			Task { @MainActor in
				switch result {
				case .success:
					Self.logger.info("Feedly: OPML import finished")
					self.isOPMLImportInProgress = false
					DispatchQueue.main.async {
						completion(.success(()))
					}
				case .failure(let error):
					Self.logger.error("Feedly: OPML import failed: \(error.localizedDescription)")
					self.isOPMLImportInProgress = false
					DispatchQueue.main.async {
						let wrappedError = AccountError.wrapped(error, account)
						completion(.failure(wrappedError))
					}
				}
			}
		}
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		try await withCheckedThrowingContinuation { continuation in
			createFolder(for: account, name: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor func createFolder(for account: Account, name: String, completion: @escaping @Sendable (Result<Folder, Error>) -> Void) {

		caller.createCollection(named: name) { result in
			Task { @MainActor in
				switch result {
				case .success(let collection):
					if let folder = account.ensureFolder(with: collection.label) {
						folder.externalID = collection.id
						completion(.success(folder))
					} else {
						// Is the name empty? Or one of the global resource names?
						completion(.failure(FeedlyAccountDelegateError.unableToAddFolder(name)))
					}
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFolder(for: account, with: folder, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		guard let id = folder.externalID else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.unableToRenameFolder(folder.nameForDisplay, name)))
			}
		}

		let nameBefore = folder.name

		caller.renameCollection(with: id, to: name) { result in
			Task { @MainActor in
				switch result {
				case .success(let collection):
					folder.name = collection.label
					completion(.success(()))
				case .failure(let error):
					folder.name = nameBefore
					completion(.failure(error))
				}
			}
		}

		folder.name = name
	}

	@MainActor func removeFolder(for account: Account, with folder: Folder) async throws {
		try await withCheckedThrowingContinuation { continuation in
			removeFolder(for: account, with: folder) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func removeFolder(for account: Account, with folder: Folder, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		guard let id = folder.externalID else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.unableToRemoveFolder(folder.nameForDisplay)))
			}
		}

		caller.deleteCollection(with: id) { result in
			Task { @MainActor in

				switch result {
				case .success:
					account.removeFolderFromTree(folder)
					completion(.success(()))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	@MainActor func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		try await withCheckedThrowingContinuation { continuation in
			createFeed(for: account, url: urlString, name: name, container: container, validateFeed: validateFeed) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {

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
														   syncUnreadIdsService: caller,
														   getStreamContentsService: caller,
														   database: syncDatabase,
														   container: container,
														   operationQueue: operationQueue)

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

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFeed(for: account, with: feed, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		let folderCollectionIds = account.folders?.filter { $0.has(feed) }.compactMap { $0.externalID }
		guard let collectionIds = folderCollectionIds, let collectionId = collectionIds.first else {
			completion(.failure(FeedlyAccountDelegateError.unableToRenameFeed(feed.nameForDisplay, name)))
			return
		}

		let feedId = FeedlyFeedResourceId(id: feed.feedID)
		let editedNameBefore = feed.editedName

		// Adding an existing feed updates it.
		// Updating feed name in one folder/collection updates it for all folders/collections.
		caller.addFeed(with: feedId, title: name, toCollectionWith: collectionId) { result in
			Task { @MainActor in
				switch result {
				case .success:
					completion(.success(()))

				case .failure(let error):
					feed.editedName = editedNameBefore
					completion(.failure(error))
				}
			}
		}

		// optimistically set the name
		feed.editedName = name
	}

	@MainActor func addFeed(account: Account, feed: Feed, container: Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			addFeed(for: account, with: feed, to: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping @MainActor (Result<Void, Error>) -> Void) {

		do {
			guard let credentials = credentials else {
				throw FeedlyAccountDelegateError.notLoggedIn
			}

			let resource = FeedlyFeedResourceId(id: feed.feedID)
            let addExistingFeed = try FeedlyAddExistingFeedOperation(account: account,
                                                                     credentials: credentials,
                                                                     resource: resource,
                                                                     service: caller,
                                                                     container: container,
                                                                     customFeedName: feed.editedName,
																	 operationQueue: operationQueue)


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

	@MainActor func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			removeFeed(for: account, with: feed, from: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		guard let folder = container as? Folder, let collectionId = folder.externalID else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.unableToRemoveFeed(feed.nameForDisplay)))
			}
		}

		caller.removeFeed(feed.feedID, fromCollectionWith: collectionId) { result in
			Task { @MainActor in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
					folder.addFeedToTreeAtTopLevel(feed)
					completion(.failure(error))
				}
			}
		}

		folder.removeFeedFromTreeAtTopLevel(feed)
	}

	@MainActor func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		try await withCheckedThrowingContinuation{ continuation in
			moveFeed(for: account, with: feed, from: sourceContainer, to: destinationContainer) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		guard let from = from as? Folder, let to = to as? Folder else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.addFeedChooseFolder))
			}
		}

		addFeed(for: account, with: feed, to: to) { [weak self] addResult in
			Task { @MainActor in
				switch addResult {
					// now that we have added the feed, remove it from the other collection
				case .success:
					self?.removeFeed(for: account, with: feed, from: from) { removeResult in
						Task { @MainActor in
							switch removeResult {
							case .success:
								completion(.success(()))
							case .failure:
								from.addFeedToTreeAtTopLevel(feed)
								completion(.failure(FeedlyAccountDelegateError.unableToMoveFeedBetweenFolders(feed.nameForDisplay, from.nameForDisplay, to.nameForDisplay)))
							}
						}
					}
				case .failure(let error):
					from.addFeedToTreeAtTopLevel(feed)
					to.removeFeedFromTreeAtTopLevel(feed)
					completion(.failure(error))
				}
			}
		}

		// optimistically move the feed, undoing as appropriate to the failure
		from.removeFeedFromTreeAtTopLevel(feed)
		to.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			restoreFeed(for: account, feed: feed, container: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			account.addFeed(existingFeed, to: container) { result in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
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

	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws {
		try await withCheckedThrowingContinuation { continuation in
			restoreFolder(for: account, folder: folder) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor private func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
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
					Self.logger.error("Feedly: Restore folder feed error: \(error.localizedDescription)")
				}
			}
		}

		group.notify(queue: .main) {
			account.addFolderToTree(folder)
			completion(.success(()))
		}
	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		let articles = try await account.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try await syncDatabase.selectPendingCount(), count > 100 {
			sendArticleStatus(for: account) { _ in }
		}
	}

	func accountDidInitialize(_ account: Account) {
		initializedAccount = account
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
	}

	func accountWillBeDeleted(_ account: Account) {
		let logout = FeedlyLogoutOperation(account: account, service: caller)
		// Dispatch on the shared queue because the lifetime of the account delegate is uncertain.
		MainThreadOperationQueue.shared.add(logout)
	}

	static func validateCredentials(transport: any Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		assertionFailure("An account instance should enqueue an \(FeedlyRefreshAccessTokenOperation.self) instead.")
		return credentials
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
		operationQueue.cancelAll()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		syncDatabase.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		syncDatabase.resume()
		caller.resume()
	}

	// MARK: - Notifications

	@objc func syncProgressDidChange(_ notification: Notification) {
		if operationQueue.isTrackingProgress {
			progressInfo = operationQueue.progressInfo
		} else {
			progressInfo = ProgressInfo()
		}
	}
}

extension FeedlyAccountDelegate: FeedlyAPICallerDelegate {

	@MainActor func reauthorizeFeedlyAPICaller(_ caller: FeedlyAPICaller, completionHandler: @escaping (Bool) -> ()) {
		guard let account = initializedAccount else {
			completionHandler(false)
			return
		}

		/// Captures a failure to refresh a token, assuming that it was refreshed unless told otherwise.
		final class RefreshAccessTokenOperationDelegate: FeedlyOperationDelegate {

			private(set) var didReauthorize = true

			func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
				didReauthorize = false
			}
		}

		let refreshAccessToken = FeedlyRefreshAccessTokenOperation(account: account, service: self, oauthClient: oauthAuthorizationClient)

		/// This must be strongly referenced by the completionBlock of the `FeedlyRefreshAccessTokenOperation`.
		let refreshAccessTokenDelegate = RefreshAccessTokenOperationDelegate()
		refreshAccessToken.delegate = refreshAccessTokenDelegate

		refreshAccessToken.completionBlock = { operation in
			assert(Thread.isMainThread)
			completionHandler(refreshAccessTokenDelegate.didReauthorize && !operation.isCanceled)
		}

		MainThreadOperationQueue.shared.add(refreshAccessToken)
	}
}
