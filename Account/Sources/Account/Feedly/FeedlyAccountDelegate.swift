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
import Secrets
import AccountError

final class FeedlyAccountDelegate: AccountDelegate, Logging {

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
	
	/// Set on `accountDidInitialize` for the purposes of refreshing OAuth tokens when they expire.
	/// See the implementation for `FeedlyAPICallerDelegate`.
	private weak var initializedAccount: Account?
	
	internal let caller: FeedlyAPICaller
	
	private let database: SyncDatabase
	
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
		self.database = SyncDatabase(databaseFilePath: databaseFilePath)
		self.oauthAuthorizationClient = api.oauthAuthorizationClient
		
		self.caller.delegate = self
	}
	
	// MARK: Account API
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		completion()
	}

	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		assert(Thread.isMainThread)
		
		guard currentSyncAllOperation == nil else {
            self.logger.debug("Ignoring refreshAll: Feedly sync already in progress.")
			completion(.success(()))
			return
		}
		
		guard let credentials = credentials else {
            self.logger.debug("Ignoring refreshAll: Feedly account has no credentials.")
			completion(.failure(FeedlyAccountDelegateError.notLoggedIn))
			return
		}
		
		let syncAllOperation = FeedlySyncAllOperation(account: account, feedlyUserID: credentials.username, caller: caller, database: database, lastSuccessfulFetchStartDate: accountMetadata?.lastArticleFetchStartTime, downloadProgress: refreshProgress)
		
		syncAllOperation.downloadProgress = refreshProgress
		
		let date = Date()
		syncAllOperation.syncCompletionHandler = { [weak self] result in
			if case .success = result {
				self?.accountMetadata?.lastArticleFetchStartTime = date
				self?.accountMetadata?.lastArticleFetchEndTime = Date()
			}
			
            self?.logger.debug("Sync took \(-date.timeIntervalSinceNow, privacy: .public) seconds.")
			completion(result)
		}
		
		currentSyncAllOperation = syncAllOperation
		
		operationQueue.add(syncAllOperation)
	}
	
	func syncArticleStatus(for account: Account, completion: ((Result<Void, Error>) -> Void)? = nil) {
		sendArticleStatus(for: account) { result in
			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						completion?(.success(()))
					case .failure(let error):
                        self.logger.error("Failed to refresh article status for account \(String(describing: account.type), privacy: .public): \(error.localizedDescription, privacy: .public)")
						completion?(.failure(error))
					}
				}
			case .failure(let error):
                self.logger.error("Failed to send article status for account \(String(describing: account.type), privacy: .public): \(error.localizedDescription, privacy: .public)")
				completion?(.failure(error))
			}
		}
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		// Ensure remote articles have the same status as they do locally.
		let send = FeedlySendArticleStatusesOperation(database: database, service: caller)
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
	/// - Parameter completion: Call on the main queue.
	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard let credentials = credentials else {
			return completion(.success(()))
		}
		
		let group = DispatchGroup()
		
		let ingestUnread = FeedlyIngestUnreadArticleIDsOperation(account: account, userID: credentials.username, service: caller, database: database, newerThan: nil)
		
		group.enter()
		ingestUnread.completionBlock = { _ in
			group.leave()
			
		}
		
		let ingestStarred = FeedlyIngestStarredArticleIDsOperation(account: account, userId: credentials.username, service: caller, database: database, newerThan: nil)
		
		group.enter()
		ingestStarred.completionBlock = { _ in
			group.leave()
		}
		
		group.notify(queue: .main) {
			completion(.success(()))
		}
		
		operationQueue.addOperations([ingestUnread, ingestStarred])
	}
	
	func importOPML(for account: Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
		let data: Data
		
		do {
			data = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}
		
        logger.debug("Begin importing OPML...")
		isOPMLImportInProgress = true
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		
		caller.importOPML(data) { result in
			switch result {
			case .success:
                self.logger.debug("Import OPML done.")
				self.refreshProgress.completeTask()
				self.isOPMLImportInProgress = false
				DispatchQueue.main.async {
					completion(.success(()))
				}
			case .failure(let error):
                self.logger.error("Import OPML failed: \(error.localizedDescription, privacy: .public)")
				self.refreshProgress.completeTask()
				self.isOPMLImportInProgress = false
				DispatchQueue.main.async {
					let wrappedError = WrappedAccountError(accountID: account.accountID, accountNameForDisplay: account.nameForDisplay, underlyingError: error)
					completion(.failure(wrappedError))
				}
			}
		}
	}
	
	func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		
		let progress = refreshProgress
		progress.addToNumberOfTasksAndRemaining(1)
		
		caller.createCollection(named: name) { result in
			progress.completeTask()
			
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
	
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let id = folder.externalID else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.unableToRenameFolder(folder.nameForDisplay, name)))
			}
		}
		
		let nameBefore = folder.name
		
		caller.renameCollection(with: id, to: name) { result in
			switch result {
			case .success(let collection):
				folder.name = collection.label
				completion(.success(()))
			case .failure(let error):
				folder.name = nameBefore
				completion(.failure(error))
			}
		}
		
		folder.name = name
	}
	
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let id = folder.externalID else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.unableToRemoveFolder(folder.nameForDisplay)))
			}
		}
		
		let progress = refreshProgress
		progress.addToNumberOfTasksAndRemaining(1)
		
		caller.deleteCollection(with: id) { result in
			progress.completeTask()
			
			switch result {
			case .success:
				account.removeFolder(folder)
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
		
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		
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
														   database: database,
														   container: container,
														   progress: refreshProgress)
			
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

    func renameFeed(for account: Account, feed: Feed, name: String) async throws {

        let folderCollectionIDs = account.folders?.filter { $0.has(feed) }.compactMap { $0.externalID }
        guard let collectionIDs = folderCollectionIDs, let collectionID = collectionIDs.first else {
            throw FeedlyAccountDelegateError.unableToRenameFeed(feed.nameForDisplay, name)
        }

        let feedID = FeedlyFeedResourceID(id: feed.feedID)
        let editedNameBefore = feed.editedName

        // optimistically set the name
        feed.editedName = name

        // Adding an existing feed updates it.
        // Updating feed name in one folder/collection updates it for all folders/collections.
        try await withCheckedThrowingContinuation { continuation in
            caller.addFeed(with: feedID, title: name, toCollectionWith: collectionID) { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        continuation.resume()

                    case .failure(let error):
                        feed.editedName = editedNameBefore
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let folderCollectionIds = account.folders?.filter { $0.has(feed) }.compactMap { $0.externalID }
		guard let collectionIds = folderCollectionIds, let collectionId = collectionIds.first else {
			completion(.failure(FeedlyAccountDelegateError.unableToRenameFeed(feed.nameForDisplay, name)))
			return
		}
		
		let feedId = FeedlyFeedResourceID(id: feed.feedID)
		let editedNameBefore = feed.editedName
		
		// Adding an existing feed updates it.
		// Updating feed name in one folder/collection updates it for all folders/collections.
		caller.addFeed(with: feedId, title: name, toCollectionWith: collectionId) { result in
			switch result {
			case .success:
				completion(.success(()))
				
			case .failure(let error):
				feed.editedName = editedNameBefore
				completion(.failure(error))
			}
		}
		
		// optimistically set the name
		feed.editedName = name
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
	
	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let folder = container as? Folder, let collectionId = folder.externalID else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.unableToRemoveFeed(feed)))
			}
		}
		
		caller.removeFeed(feed.feedID, fromCollectionWith: collectionId) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				folder.addFeed(feed)
				completion(.failure(error))
			}
		}
		
		folder.removeFeed(feed)
	}
	
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let from = from as? Folder, let to = to as? Folder else {
			return DispatchQueue.main.async {
				completion(.failure(FeedlyAccountDelegateError.addFeedChooseFolder))
			}
		}
		
		addFeed(for: account, with: feed, to: to) { [weak self] addResult in
			switch addResult {
				// now that we have added the feed, remove it from the other collection
			case .success:
				self?.removeFeed(for: account, with: feed, from: from) { removeResult in
					switch removeResult {
					case .success:
						completion(.success(()))
					case .failure:
						from.addFeed(feed)
						completion(.failure(FeedlyAccountDelegateError.unableToMoveFeedBetweenFolders(feed, from, to)))
					}
				}
			case .failure(let error):
				from.addFeed(feed)
				to.removeFeed(feed)
				completion(.failure(error))
			}
			
		}
		
		// optimistically move the feed, undoing as appropriate to the failure
		from.removeFeed(feed)
		to.addFeed(feed)
	}
	
	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
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
	
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
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
                    self.logger.error("Restore folder feed error: \(error.localizedDescription, privacy: .public)")
				}
			}
			
		}
		
		group.notify(queue: .main) {
			account.addFolder(folder)
			completion(.success(()))
		}
	}
	
	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in

			Task { @MainActor in
				switch result {
				case .success(let articles):
					let syncStatuses = articles.map { article in
						return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
					}

					do {
						try await self.database.insertStatuses(syncStatuses)
						let count = try await self.database.selectPendingCount()
						if count > 100 {
							self.sendArticleStatus(for: account) { _ in }
						}
						completion(.success(()))
					} catch {
						completion(.failure(error))
					}
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		initializedAccount = account
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
		refreshProgress.name = account.nameForDisplay
	}
	
	func accountWillBeDeleted(_ account: Account) {
		let logout = FeedlyLogoutOperation(account: account, service: caller)
		// Dispatch on the shared queue because the lifetime of the account delegate is uncertain.
		MainThreadOperationQueue.shared.add(logout)
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		assertionFailure("An `account` instance should enqueue an \(FeedlyRefreshAccessTokenOperation.self) instead.")
		completion(.success(credentials))
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
		operationQueue.cancelAllOperations()
	}
	
	/// Suspend the SQLLite databases
	func suspendDatabase() {
		database.suspend()
	}
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		database.resume()
		caller.resume()
	}
}

extension FeedlyAccountDelegate: FeedlyAPICallerDelegate {
	
	func reauthorizeFeedlyAPICaller(_ caller: FeedlyAPICaller, completionHandler: @escaping (Bool) -> ()) {
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
		refreshAccessToken.downloadProgress = refreshProgress
		
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
