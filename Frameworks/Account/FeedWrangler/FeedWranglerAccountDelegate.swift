//
//  FeedWranglerAccountDelegate.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-08-29.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os.log

final class FeedWranglerAccountDelegate: AccountDelegate {
	
	var behaviors: AccountBehaviors = []
	
	var isOPMLImportInProgress = false
	var server: String? = FeedWranglerConfig.clientPath
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	var accountMetadata: AccountMetadata?
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	private let caller: FeedWranglerAPICaller
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feed Wrangler")
	private let database: SyncDatabase
	
	init(dataFolder: String, transport: Transport?) {
		if let transport = transport {
			caller = FeedWranglerAPICaller(transport: transport)
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
			caller = FeedWranglerAPICaller(transport: session)
		}
		
		database = SyncDatabase(databaseFilePath: dataFolder.appending("/Sync.sqlite3"))
	}
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(6)
		
		self.refreshCredentials(for: account) {
			self.refreshSubscriptions(for: account) { _ in
				self.sendArticleStatus(for: account) {
					self.refreshArticleStatus(for: account) {
						self.refreshArticles(for: account) {
							self.refreshMissingArticles(for: account) {
								self.refreshProgress.clear()
								DispatchQueue.main.async {
									completion(.success(()))
								}
							}
						}
					}
				}
			}
		}
	}
	
	func refreshCredentials(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "Refreshing credentials...")
		// MARK: TODO
		credentials = try? account.retrieveCredentials(type: .feedWranglerToken)
		completion()
	}
	
	func refreshSubscriptions(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		os_log(.debug, log: log, "Refreshing subscriptions...")
		caller.retrieveSubscriptions { result in
			switch result {
			case .success(let subscriptions):
				self.syncFeeds(account, subscriptions)
				completion(.success(()))
				
			case .failure(let error):
				os_log(.debug, log: self.log, "Failed to refresh subscriptions: %@", error.localizedDescription)
				completion(.failure(error))
			}
			
		}
	}
	
	func refreshArticles(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "Refreshing articles...")
		completion()
	}
	
	func refreshMissingArticles(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "Refreshing missing articles...")
		completion()
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "Sending article status...")
		completion()
	}
	
	func refreshArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "Refreshing article status...")
		completion()
	}
	
	func importOPML(for account: Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func addFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		fatalError()
	}
	
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func createFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		fatalError()
	}
	
	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func addFeed(for account: Account, with: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		fatalError()
	}
	
	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		fatalError()
	}
	
	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .feedWranglerToken)
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		let caller = FeedWranglerAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			DispatchQueue.main.async {
				completion(result)
			}
		}
	}
}

// MARK: Private
private extension FeedWranglerAccountDelegate {
	
	func syncFeeds(_ account: Account, _ subscriptions: [FeedWranglerSubscription]) {
		assert(Thread.isMainThread)
		let feedIds = subscriptions.map { String($0.feedID) }
		
		let feedsToRemove = account.topLevelFeeds.filter { !feedIds.contains($0.feedID) }
		account.removeFeeds(feedsToRemove)

		var subscriptionsToAdd = Set<FeedWranglerSubscription>()
		subscriptions.forEach { subscription in
			let subscriptionId = String(subscription.feedID)
			
			if let feed = account.existingFeed(withFeedID: subscriptionId) {
				feed.name = subscription.title
				feed.homePageURL = subscription.siteURL
				feed.subscriptionID = nil // MARK: TODO What should this be?
			} else {
				subscriptionsToAdd.insert(subscription)
			}
		}
		
		subscriptionsToAdd.forEach { subscription in
			let feedId = String(subscription.feedID)
			let feed = account.createFeed(with: subscription.title, url: subscription.feedURL, feedID: feedId, homePageURL: subscription.siteURL)
			feed.subscriptionID = nil
			account.addFeed(feed)
		}
	}
}
