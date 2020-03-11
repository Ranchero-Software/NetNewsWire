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

	private let caller: NewsBlurAPICaller
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "NewsBlur")
	private let database: SyncDatabase

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

		refreshSubscriptions(for: account) { result in
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
								self.refreshArticles(for: account) { result in
									self.refreshProgress.completeTask()

									switch result {
									case .success:
										self.refreshMissingArticles(for: account) { result in
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
		completion(.success(()))
	}

	func refreshArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	func refreshArticles(for account: Account, completion: @escaping (Result<[NewsBlurArticleHash], Error>) -> Void) {
		os_log(.debug, log: log, "Refreshing articles...")

		caller.retrieveUnreadArticleHashes { result in
			switch result {
			case .success(let articleHashes):
				print(articleHashes)
			case .failure(let error):
				break
			}
		}
	}

	func refreshMissingArticles(for account: Account, completion: @escaping (Result<Void, Error>)-> Void) {
		completion(.success(()))
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
		fatalError("markArticles(for:articles:statusKey:flag:) has not been implemented")
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

	func suspendNetwork() {
	}

	func suspendDatabase() {
		database.suspend()
	}

	func resume() {
		database.resume()
	}
}

extension NewsBlurAccountDelegate {
	private func refreshSubscriptions(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		os_log(.debug, log: log, "Refreshing subscriptions...")

		caller.retrieveSubscriptions { result in
			switch result {
			case .success(let subscriptions):
				print(subscriptions)
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}
