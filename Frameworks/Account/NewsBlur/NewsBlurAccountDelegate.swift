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

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func sendArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		os_log(.debug, log: log, "Sending story statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				let createUnreadStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.read && $0.flag == false }
				let deleteUnreadStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.read && $0.flag == true }
				let createStarredStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.starred && $0.flag == true }
				let deleteStarredStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.starred && $0.flag == false }

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

				self.refreshUnreadStories(for: account, hashes: storyHashes, updateFetchDate: nil, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func refreshMissingStories(for account: Account, completion: @escaping (Result<Void, Error>)-> Void) {
		completion(.success(()))
	}
	
	func processStories(account: Account, stories: [NewsBlurStory]?, completion: @escaping DatabaseCompletionBlock) {
		let parsedItems = mapStoriesToParsedItems(stories: stories)
		let webFeedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
		account.update(webFeedIDsAndItems: webFeedIDsAndItems, defaultRead: true, completion: completion)
	}

	func importOPML(for account: Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func addFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> ()) {
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func createWebFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> ()) {
	}

	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func addWebFeed(for account: Account, with: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func moveWebFeed(for account: Account, with feed: WebFeed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func restoreWebFeed(for account: Account, feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		}
		database.insertStatuses(syncStatuses)

		database.selectPendingCount { result in
			if let count = try? result.get(), count > 100 {
				self.sendArticleStatus(for: account) { _ in }
			}
		}

		return try? account.update(articles, statusKey: statusKey, flag: flag)
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
