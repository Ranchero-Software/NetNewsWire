//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSDatabase
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

final class NewsBlurAccountDelegate: AccountDelegate {

	var behaviors: AccountBehaviors = []

	var isOPMLImportInProgress: Bool = false
	var server: String? = "newsblur.com"
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	var accountMetadata: AccountMetadata? = nil
	var refreshProgress = DownloadProgress(numberOfTasks: 0)

	let caller: NewsBlurAPICaller
	let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "NewsBlur")
	let database: SyncDatabase

	init(dataFolder: String, transport: Transport?) {
		if let transport = transport {
			caller = NewsBlurAPICaller(transport: transport)
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
			caller = NewsBlurAPICaller(transport: session)
		}

		database = SyncDatabase(databaseFilePath: dataFolder.appending("/DB.sqlite3"))
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		completion()
	}
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		self.refreshProgress.addToNumberOfTasksAndRemaining(5)

		refreshFeeds(for: account) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				self.sendArticleStatus(for: account) { result in
					self.refreshProgress.completeTask()

					switch result {
					case .success:
						self.refreshArticleStatus(for: account) { result in
							self.refreshProgress.completeTask()

							switch result {
							case .success:
								self.refreshStories(for: account) { result in
									self.refreshProgress.completeTask()

									switch result {
									case .success:
										self.refreshMissingStories(for: account) { result in
											self.refreshProgress.completeTask()

											switch result {
											case .success:
												DispatchQueue.main.async {
													completion(.success(()))
												}

											case .failure(let error):
												DispatchQueue.main.async {
													self.refreshProgress.clear()
													let wrappedError = AccountError.wrappedError(error: error, account: account)
													completion(.failure(wrappedError))
												}
											}
										}

									case .failure(let error):
										completion(.failure(error))
									}
								}

							case .failure(let error):
								completion(.failure(error))
							}
						}

					case .failure(let error):
						completion(.failure(error))
					}
				}

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func sendArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		os_log(.debug, log: log, "Sending story statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				let createUnreadStatuses = syncStatuses.filter {
					$0.key == SyncStatus.Key.read && $0.flag == false
				}
				let deleteUnreadStatuses = syncStatuses.filter {
					$0.key == SyncStatus.Key.read && $0.flag == true
				}
				let createStarredStatuses = syncStatuses.filter {
					$0.key == SyncStatus.Key.starred && $0.flag == true
				}
				let deleteStarredStatuses = syncStatuses.filter {
					$0.key == SyncStatus.Key.starred && $0.flag == false
				}

				let group = DispatchGroup()
				var errorOccurred = false

				group.enter()
				self.sendStoryStatuses(createUnreadStatuses, throttle: true, apiCall: self.caller.markAsUnread) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.enter()
				self.sendStoryStatuses(deleteUnreadStatuses, throttle: false, apiCall: self.caller.markAsRead) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.enter()
				self.sendStoryStatuses(createStarredStatuses, throttle: true, apiCall: self.caller.star) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.enter()
				self.sendStoryStatuses(deleteStarredStatuses, throttle: true, apiCall: self.caller.unstar) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.notify(queue: DispatchQueue.main) {
					os_log(.debug, log: self.log, "Done sending article statuses.")
					if errorOccurred {
						completion(.failure(NewsBlurError.unknown))
					} else {
						completion(.success(()))
					}
				}
			}

			switch result {
			case .success(let syncStatuses):
				processStatuses(syncStatuses)
			case .failure(let databaseError):
				completion(.failure(databaseError))
			}
		}
	}

	func refreshArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		os_log(.debug, log: log, "Refreshing story statuses...")

		let group = DispatchGroup()
		var errorOccurred = false

		group.enter()
		caller.retrieveUnreadStoryHashes { result in
			switch result {
			case .success(let storyHashes):
				self.syncStoryReadState(account: account, hashes: storyHashes)
				group.leave()
			case .failure(let error):
				errorOccurred = true
				os_log(.info, log: self.log, "Retrieving unread stories failed: %@.", error.localizedDescription)
				group.leave()
			}
		}

		group.enter()
		caller.retrieveStarredStoryHashes { result in
			switch result {
			case .success(let storyHashes):
				self.syncStoryStarredState(account: account, hashes: storyHashes)
				group.leave()
			case .failure(let error):
				errorOccurred = true
				os_log(.info, log: self.log, "Retrieving starred stories failed: %@.", error.localizedDescription)
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			if errorOccurred {
				completion(.failure(NewsBlurError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}

	func refreshStories(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		os_log(.debug, log: log, "Refreshing stories...")
		os_log(.debug, log: log, "Refreshing unread stories...")

		caller.retrieveUnreadStoryHashes { result in
			switch result {
			case .success(let storyHashes):
				self.refreshProgress.completeTask()

				if let count = storyHashes?.count, count > 0 {
					self.refreshProgress.addToNumberOfTasksAndRemaining((count - 1) / 100 + 1)
				}

				self.refreshUnreadStories(for: account, hashes: storyHashes, updateFetchDate: nil, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func refreshMissingStories(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		os_log(.debug, log: log, "Refreshing missing stories...")

		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in

			func process(_ fetchedHashes: Set<String>) {
				let group = DispatchGroup()
				var errorOccurred = false

				let storyHashes = Array(fetchedHashes).map {
					NewsBlurStoryHash(hash: $0, timestamp: Date())
				}
				let chunkedStoryHashes = storyHashes.chunked(into: 100)

				for chunk in chunkedStoryHashes {
					group.enter()
					self.caller.retrieveStories(hashes: chunk) { result in

						switch result {
						case .success((let stories, _)):
							self.processStories(account: account, stories: stories) { result in
								group.leave()
								if case .failure = result {
									errorOccurred = true
								}
							}
						case .failure(let error):
							errorOccurred = true
							os_log(.error, log: self.log, "Refresh missing stories failed: %@.", error.localizedDescription)
							group.leave()
						}
					}
				}

				group.notify(queue: DispatchQueue.main) {
					self.refreshProgress.completeTask()
					os_log(.debug, log: self.log, "Done refreshing missing stories.")
					if errorOccurred {
						completion(.failure(NewsBlurError.unknown))
					} else {
						completion(.success(()))
					}
				}
			}

			switch result {
			case .success(let fetchedArticleIDs):
				process(fetchedArticleIDs)
			case .failure(let error):
				self.refreshProgress.completeTask()
				completion(.failure(error))
			}
		}
	}

	func processStories(account: Account, stories: [NewsBlurStory]?, since: Date? = nil, completion: @escaping (Result<Bool, DatabaseError>) -> Void) {
		let parsedItems = mapStoriesToParsedItems(stories: stories).filter {
			guard let datePublished = $0.datePublished, let since = since else {
				return true
			}

			return datePublished >= since
		}
		let webFeedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues {
			Set($0)
		}

		account.update(webFeedIDsAndItems: webFeedIDsAndItems, defaultRead: true) { error in
			if let error = error {
				completion(.failure(error))
				return
			}

			completion(.success(!webFeedIDsAndItems.isEmpty))
		}
	}

	func importOPML(for account: Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> ()) {
		self.refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.addFolder(named: name) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success():
				if let folder = account.ensureFolder(with: name) {
					completion(.success(folder))
				} else {
					completion(.failure(NewsBlurError.invalidParameter))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folderToRename = folder.name else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		let nameBefore = folder.name

		caller.renameFolder(with: folderToRename, to: name) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				folder.name = nameBefore
				completion(.failure(error))
			}
		}

		folder.name = name
	}

	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folderToRemove = folder.name else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		var feedIDs: [String] = []
		for feed in folder.topLevelWebFeeds {
			if (feed.folderRelationship?.count ?? 0) > 1 {
				clearFolderRelationship(for: feed, withFolderName: folderToRemove)
			} else if let feedID = feed.externalID {
				feedIDs.append(feedID)
			}
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.removeFolder(named: folderToRemove, feedIDs: feedIDs) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				account.removeFolder(folder)
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func createWebFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> ()) {
		refreshProgress.addToNumberOfTasksAndRemaining(1)

		let folderName = (container as? Folder)?.name
		caller.addURL(url, folder: folderName) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success(let feed):
				self.createFeed(account: account, feed: feed, name: name, container: container, completion: completion)
			case .failure(let error):
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}
	}

	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let feedID = feed.externalID else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.renameFeed(feedID: feedID, newName: name) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				DispatchQueue.main.async {
					feed.editedName = name
					completion(.success(()))
				}

			case .failure(let error):
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}
	}

	func addWebFeed(for account: Account, with feed: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folder = container as? Folder else {
			DispatchQueue.main.async {
				if let account = container as? Account {
					account.addWebFeed(feed)
				}
				completion(.success(()))
			}

			return
		}

		let folderName = folder.name ?? ""
		saveFolderRelationship(for: feed, withFolderName: folderName, id: folderName)
		folder.addWebFeed(feed)

		completion(.success(()))
	}

	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		deleteFeed(for: account, with: feed, from: container, completion: completion)
	}

	func moveWebFeed(for account: Account, with feed: WebFeed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let feedID = feed.externalID else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.moveFeed(
				feedID: feedID,
				from: (from as? Folder)?.name,
				to: (to as? Folder)?.name
		) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				from.removeWebFeed(feed)
				to.addWebFeed(feed)
				
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func restoreWebFeed(for account: Account, feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		if let existingFeed = account.existingWebFeed(withURL: feed.url) {
			account.addWebFeed(existingFeed, to: container) { result in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		} else {
			createWebFeed(for: account, url: feed.url, name: feed.editedName, container: container) { result in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folderName = folder.name else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		var feedsToRestore: [WebFeed] = []
		for feed in folder.topLevelWebFeeds {
			feedsToRestore.append(feed)
			folder.topLevelWebFeeds.remove(feed)
		}

		let group = DispatchGroup()

		group.enter()
		createFolder(for: account, name: folderName) { result in
			group.leave()
			switch result {
			case .success(let folder):
				for feed in feedsToRestore {
					group.enter()
					self.restoreWebFeed(for: account, feed: feed, container: folder) { result in
						group.leave()
						switch result {
						case .success:
							break
						case .failure(let error):
							os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
						}
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in
			switch result {
			case .success(let articles):
				let syncStatuses = articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				}

				self.database.insertStatuses(syncStatuses) { _ in
					self.database.selectPendingCount { result in
						if let count = try? result.get(), count > 100 {
							self.sendArticleStatus(for: account) { _ in }
						}
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "Error marking article status: %@", error.localizedDescription)
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .newsBlurSessionId)
	}

	func accountWillBeDeleted(_ account: Account) {
		caller.logout() { _ in }
	}

	class func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, completion: @escaping (Result<Credentials?, Error>) -> ()) {
		let caller = NewsBlurAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			DispatchQueue.main.async {
				completion(result)
			}
		}
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		database.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		caller.resume()
		database.resume()
	}
}
