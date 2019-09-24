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
				caller.credentials = Credentials(type: .oauthAccessToken, username: "", secret: devToken)
			} else {
				caller.credentials = credentials
			}
		}
	}
	
	var accountMetadata: AccountMetadata?
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	private let database: SyncDatabase
	private let caller: FeedlyAPICaller
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feedly")
	
	init(dataFolder: String, transport: Transport?, api: FeedlyAPICaller.API = .default) {
		
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		database = SyncDatabase(databaseFilePath: databaseFilePath)
				
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
			DispatchQueue.main.async {
				progress.completeTask()
			}
		}
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "*** SKIPPING SEND ARTICLE STATUS ***")
		completion()
	}
	
	func refreshArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		os_log(.debug, log: log, "*** SKIPPING REFRESH ARTICLE STATUS ***")
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
		
		let log = self.log
		
		switch statusKey {
		case .read:
			let ids = articles.map { $0.articleID }
			caller.markAsRead(articleIds: ids) { result in
				switch result {
				case .success:
					account.update(articles, statusKey: statusKey, flag: flag)
				case .failure(let error):
					os_log(.debug, log: log, "*** SKIPPING MARKING ARTICLES READ: %@ %@ ***", error as NSError, ids)
				}
				
			}
		default:
			os_log(.debug, log: log, "*** SKIPPING STATUS UPDATE FOR ARTICLES: %@ ***", articles)
		}
		
		return nil
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .oauthAccessToken)
		
		syncStrategy = FeedlySyncStrategy(account: account, caller: caller, log: log)
		
		//TODO: Figure out how other accounts get refreshed automatically.
		refreshAll(for: account) { result in
			print("sync after initialise did complete")
		}
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		fatalError()
	}
}
