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

	func refreshArticles(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		os_log(.debug, log: log, "Refreshing articles...")
		os_log(.debug, log: log, "Refreshing unread articles...")

		caller.retrieveUnreadArticleHashes { result in
			switch result {
			case .success(let articleHashes):
				self.refreshProgress.completeTask()

				self.refreshUnreadArticles(for: account, hashes: articleHashes, updateFetchDate: nil, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func refreshUnreadArticles(for account: Account, hashes: [NewsBlurArticleHash]?, updateFetchDate: Date?, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let hashes = hashes, !hashes.isEmpty else {
			if let lastArticleFetch = updateFetchDate {
				self.accountMetadata?.lastArticleFetchStartTime = lastArticleFetch
				self.accountMetadata?.lastArticleFetchEndTime = Date()
			}
			completion(.success(()))
			return
		}

		let numberOfArticles = min(hashes.count, 100) // api limit
		let hashesToFetch = Array(hashes[..<numberOfArticles])

		caller.retrieveArticles(hashes: hashesToFetch) { result in
			switch result {
			case .success(let articles):
				self.processArticles(account: account, articles: articles) { error in
					self.refreshProgress.completeTask()

					if let error = error {
						completion(.failure(error))
						return
					}

					self.refreshUnreadArticles(for: account, hashes: Array(hashes[numberOfArticles...]), updateFetchDate: updateFetchDate, completion: completion)
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func refreshMissingArticles(for account: Account, completion: @escaping (Result<Void, Error>)-> Void) {
		completion(.success(()))
	}
	
	func processArticles(account: Account, articles: [NewsBlurArticle]?, completion: @escaping DatabaseCompletionBlock) {
		let parsedItems = mapArticlesToParsedItems(articles: articles)
		let webFeedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
		account.update(webFeedIDsAndItems: webFeedIDsAndItems, defaultRead: true, completion: completion)
	}

	func mapArticlesToParsedItems(articles: [NewsBlurArticle]?) -> Set<ParsedItem> {
		guard let articles = articles else {
			return Set<ParsedItem>()
		}

		let parsedItems: [ParsedItem] = articles.map { article in
			let author = Set([ParsedAuthor(name: article.authorName, url: nil, avatarURL: nil, emailAddress: nil)])
			return ParsedItem(syncServiceID: article.articleId, uniqueID: String(article.articleId), feedURL: String(article.feedId), url: article.url, externalURL: nil, title: article.title, contentHTML: article.contentHTML, contentText: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: article.datePublished, dateModified: nil, authors: author, tags: nil, attachments: nil)
		}

		return Set(parsedItems)
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
