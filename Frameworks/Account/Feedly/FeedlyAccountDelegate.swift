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

final class FeedlyAccountDelegate: AccountDelegate {

	// TODO: Kiel, if you decide not to support OPML import you will have to disallow it in the behaviors
	// See https://developer.feedly.com/v3/opml/
	var behaviors: AccountBehaviors = [.disallowFeedInRootFolder]
	
	let isOPMLImportSupported = false
	
	var isOPMLImportInProgress = false
	
	var server: String? {
		return caller.server
	}
	
	var credentials: Credentials? {
		didSet {
			// https://developer.feedly.com/v3/developer/
			if let devToken = ProcessInfo.processInfo.environment["FEEDLY_DEV_ACCESS_TOKEN"], !devToken.isEmpty {
				caller.credentials = Credentials(type: .oauthAccessToken, username: "Developer", secret: devToken)
			} else {
				caller.credentials = credentials
			}
		}
	}
	
	var accountMetadata: AccountMetadata?
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	private let caller: FeedlyAPICaller
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feedly")
	private let database: SyncDatabase
	
	init(dataFolder: String, transport: Transport?, api: FeedlyAPICaller.API = .default) {
		
		if let transport = transport {
			caller = FeedlyAPICaller(transport: transport, api: api)
			
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
			caller = FeedlyAPICaller(transport: session, api: api)
		}
		
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.database = SyncDatabase(databaseFilePath: databaseFilePath)
	}
	
	// MARK: Account API
	
	private var syncStrategy: FeedlySyncStrategy?
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		let date = Date()
		let log = self.log
		let progress = refreshProgress
		progress.addToNumberOfTasksAndRemaining(1)
		syncStrategy?.startSync { result in
			os_log(.debug, log: log, "Sync took %.3f seconds", -date.timeIntervalSinceNow)
			progress.completeTask()
			completion(result)
		}
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		// Ensure remote articles have the same status as they do locally.
		let send = FeedlySendArticleStatusesOperation(database: database, caller: caller, log: log)
		send.completionBlock = {
			DispatchQueue.main.async {
				completion()
			}
		}
		OperationQueue.main.addOperation(send)
	}
	
	/// Attempts to ensure local articles have the same status as they do remotely.
	/// So if the user is using another client roughly simultaneously with this app,
	/// this app does its part to ensure the articles have a consistent status between both.
	///
	/// Feedly has no API that allows the app to fetch the identifiers of unread articles only.
	/// The only way to identify unread articles is to pull all of the article data,
	/// which is effectively equivalent of a full refresh.
	///
	/// - Parameter account: The account whose articles have a remote status.
	/// - Parameter completion: Call on the main queue.
	func refreshArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		refreshAll(for: account) { _ in
			completion()
		}
	}
	
	func importOPML(for account: Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
		let data: Data
		
		do {
			data = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}
		
		os_log(.debug, log: log, "Begin importing OPML...")
		isOPMLImportInProgress = true
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		
		caller.importOpml(data) { result in
			switch result {
			case .success:
				os_log(.debug, log: self.log, "Import OPML done.")
				self.refreshProgress.completeTask()
				self.isOPMLImportInProgress = false
				DispatchQueue.main.async {
					completion(.success(()))
				}
			case .failure(let error):
				os_log(.debug, log: self.log, "Import OPML failed.")
				self.refreshProgress.completeTask()
				self.isOPMLImportInProgress = false
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}
	}
	
	func addFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		
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
	
	var createFeedRequest: FeedlyAddFeedRequest?
	
	func createFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {

		let progress = refreshProgress
		progress.addToNumberOfTasksAndRemaining(1)
		
		let request = FeedlyAddFeedRequest(account: account, caller: caller, container: container, log: log)
		
		self.createFeedRequest = request
		
		request.addNewFeed(at: url, name: name) { [weak self] result in
			progress.completeTask()
			self?.createFeedRequest = nil
			completion(result)
		}
	}
	
	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
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
	
	var addFeedRequest: FeedlyAddFeedRequest?
	
	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {

		let progress = refreshProgress
		progress.addToNumberOfTasksAndRemaining(1)
		
		let request = FeedlyAddFeedRequest(account: account, caller: caller, container: container, log: log)
		
		self.addFeedRequest = request
		
		request.add(existing: feed) { [weak self] result in
			progress.completeTask()
			
			self?.addFeedRequest = nil
			
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
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
			createFeed(for: account, url: feed.url, name: feed.editedName, container: container) { result in
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
					os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
				}
			}
			
		}
		
		group.notify(queue: .main) {
			account.addFolder(folder)
			completion(.success(()))
		}
	}
	
	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		
		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		}
		
		database.insertStatuses(syncStatuses)
		os_log(.debug, log: log, "Marking %@ as %@.", articles.map { $0.title }, syncStatuses)
		
		if database.selectPendingCount() > 100 {
			sendArticleStatus(for: account) { }
		}
		
		return account.update(articles, statusKey: statusKey, flag: flag)
	}
	
	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
		
		syncStrategy = FeedlySyncStrategy(account: account,
										  caller: caller,
										  database: database,
										  log: log)
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		fatalError()
	}
}
