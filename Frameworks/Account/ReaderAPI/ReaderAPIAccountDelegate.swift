//
//  ReaderAPIAccountDelegate.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os.log

public enum ReaderAPIAccountDelegateError: String, Error {
	case invalidParameter = "There was an invalid parameter passed."
	case invalidResponse = "There was an invalid response from the server."
}

final class ReaderAPIAccountDelegate: AccountDelegate {
	
	private let database: SyncDatabase
	
	private let caller: ReaderAPICaller
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ReaderAPI")

	var behaviors: AccountBehaviors = [.disallowFeedInRootFolder, .disallowOPMLImports]

	var server: String? {
		get {
			return caller.server
		}
	}
	
	var isOPMLImportInProgress = false
	
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	weak var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	init(dataFolder: String, transport: Transport?) {
		
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		database = SyncDatabase(databaseFilePath: databaseFilePath)
		
		if transport != nil {
			
			caller = ReaderAPICaller(transport: transport!)
			
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
			
			caller = ReaderAPICaller(transport: URLSession(configuration: sessionConfiguration))
			
		}
		
	}
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		refreshProgress.addToNumberOfTasksAndRemaining(6)
		
		refreshAccount(account) { result in
			switch result {
			case .success():
				
				self.sendArticleStatus(for: account) { _ in
					self.refreshArticleStatus(for: account) { _ in
						self.refreshArticles(account) {
							self.refreshMissingArticles(account) {
								self.refreshProgress.clear()
								DispatchQueue.main.async {
									completion(.success(()))
								}
							}
						}
					}
				}

			case .failure(let error):
				DispatchQueue.main.async {
					self.refreshProgress.clear()
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
			
		}
		
	}

	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		os_log(.debug, log: log, "Sending article statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				let createUnreadStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.read && $0.flag == false }
				let deleteUnreadStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.read && $0.flag == true }
				let createStarredStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.starred && $0.flag == true }
				let deleteStarredStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.starred && $0.flag == false }

				let group = DispatchGroup()

				group.enter()
				self.sendArticleStatuses(createUnreadStatuses, apiCall: self.caller.createUnreadEntries) {
					group.leave()
				}

				group.enter()
				self.sendArticleStatuses(deleteUnreadStatuses, apiCall: self.caller.deleteUnreadEntries) {
					group.leave()
				}

				group.enter()
				self.sendArticleStatuses(createStarredStatuses, apiCall: self.caller.createStarredEntries) {
					group.leave()
				}

				group.enter()
				self.sendArticleStatuses(deleteStarredStatuses, apiCall: self.caller.deleteStarredEntries) {
					group.leave()
				}

				group.notify(queue: DispatchQueue.main) {
					os_log(.debug, log: self.log, "Done sending article statuses.")
					completion(.success(()))
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
	
	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		
		os_log(.debug, log: log, "Refreshing article statuses...")
		
		let group = DispatchGroup()
		
		group.enter()
		caller.retrieveUnreadEntries() { result in
			switch result {
			case .success(let articleIDs):
				self.syncArticleReadState(account: account, articleIDs: articleIDs)
				group.leave()
			case .failure(let error):
				os_log(.info, log: self.log, "Retrieving unread entries failed: %@.", error.localizedDescription)
				group.leave()
			}
			
		}
		
		group.enter()
		caller.retrieveStarredEntries() { result in
			switch result {
			case .success(let articleIDs):
				self.syncArticleStarredState(account: account, articleIDs: articleIDs)
				group.leave()
			case .failure(let error):
				os_log(.info, log: self.log, "Retrieving starred entries failed: %@.", error.localizedDescription)
				group.leave()
			}

		}
		
		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			completion(.success(()))
		}
		
	}
	
	func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
	}
	
	func addFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		if let folder = account.ensureFolder(with: name) {
			completion(.success(folder))
		} else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
		}
	}
	
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.renameTag(oldName: folder.name ?? "", newName: name) { result in
			switch result {
			case .success:
				DispatchQueue.main.async {
					folder.name = name
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

	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		let group = DispatchGroup()
		
		for feed in folder.topLevelWebFeeds {
			group.enter()
			removeWebFeed(for: account, with: feed, from: folder) { result in
				group.leave()
				switch result {
				case .success:
					break
				case .failure(let error):
					os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
				}
			}
		}
		
		group.notify(queue: DispatchQueue.main) {
			self.caller.deleteTag(name: folder.name!) { (result) in
				switch result {
				case .success:
					account.removeFolder(folder)
					completion(.success(()))
				case .failure(let error):
					os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
				}
				
			}
			
		}
		
	}
	
	func createWebFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		
		caller.createSubscription(url: url) { result in
			switch result {
			case .success(let subResult):
				switch subResult {
				case .created(let subscription):
					self.createFeed(account: account, subscription: subscription, name: name, container: container, completion: completion)
				case .alreadySubscribed:
					DispatchQueue.main.async {
						completion(.failure(AccountError.createErrorAlreadySubscribed))
					}
				case .notFound:
					DispatchQueue.main.async {
						completion(.failure(AccountError.createErrorNotFound))
					}
				}
			case .failure(let error):
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
			
		}
		
	}
	
	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		// This error should never happen
		guard let subscriptionID = feed.subscriptionID else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
			return
		}
		
		caller.renameSubscription(subscriptionID: subscriptionID, newName: name) { result in
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
	
	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if feed.folderRelationship?.count ?? 0 > 1 {
			deleteTagging(for: account, with: feed, from: container, completion: completion)
		} else {
			account.clearWebFeedMetadata(feed)
			deleteSubscription(for: account, with: feed, from: container, completion: completion)
		}
	}
	
	func moveWebFeed(for account: Account, with feed: WebFeed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if from is Account {
			addWebFeed(for: account, with: feed, to: to, completion: completion)
		} else {
			deleteTagging(for: account, with: feed, from: from) { result in
				switch result {
				case .success:
					self.addWebFeed(for: account, with: feed, to: to, completion: completion)
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}
	
	func addWebFeed(for account: Account, with feed: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = container as? Folder, let feedName = feed.subscriptionID {
			caller.createTagging(subscriptionID: feedName, tagName: folder.name ?? "") { result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: feed.subscriptionID!)
						account.removeWebFeed(feed)
						folder.addWebFeed(feed)
						completion(.success(()))
					}
				case .failure(let error):
					DispatchQueue.main.async {
						let wrappedError = AccountError.wrappedError(error: error, account: account)
						completion(.failure(wrappedError))
					}
				}
			}
		} else {
			DispatchQueue.main.async {
				if let account = container as? Account {
					account.addFeedIfNotInAnyFolder(feed)
				}
				completion(.success(()))
			}
		}
		
	}
	
	func restoreWebFeed(for account: Account, feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		
		createWebFeed(for: account, url: feed.url, name: feed.editedName, container: container) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		
		account.addFolder(folder)
		let group = DispatchGroup()
		
		for feed in folder.topLevelWebFeeds {
			
			group.enter()
			addWebFeed(for: account, with: feed, to: folder) { result in
				if account.topLevelWebFeeds.contains(feed) {
					account.removeWebFeed(feed)
				}
				group.leave()
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
		
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
		credentials = try? account.retrieveCredentials(type: .readerAPIKey)
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		guard let endpoint = endpoint else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let caller = ReaderAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials(endpoint: endpoint) { result in
			DispatchQueue.main.async {
				completion(result)
			}
		}
		
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.cancelAll()
	}
	
	/// Suspend the SQLLite databases
	func suspendDatabase() {
		database.suspend()
	}
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		database.resume()
	}
}

// MARK: Private

private extension ReaderAPIAccountDelegate {
	
	func refreshAccount(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveTags { result in
			switch result {
			case .success(let tags):
				BatchUpdate.shared.perform {
					self.syncFolders(account, tags)
				}
				self.refreshProgress.completeTask()
				self.refreshFeeds(account, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func syncFolders(_ account: Account, _ tags: [ReaderAPITag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing folders with %ld tags.", tags.count)

		let tagNames = tags.filter { $0.type == "folder" }.map { $0.tagID.replacingOccurrences(of: "user/-/label/", with: "") }

		// Delete any folders not at Reader
		if let folders = account.folders {
			folders.forEach { folder in
				if !tagNames.contains(folder.name ?? "") {
					for feed in folder.topLevelWebFeeds {
						account.addWebFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolder(folder)
				}
			}
		}
		
		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders Reader has, but we don't
		tagNames.forEach { tagName in
			if !folderNames.contains(tagName) {
				_ = account.ensureFolder(with: tagName)
			}
		}
		
	}
	
	func refreshFeeds(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveSubscriptions { result in
			switch result {
			case .success(let subscriptions):
				
				self.refreshProgress.completeTask()

				BatchUpdate.shared.perform {
					self.syncFeeds(account, subscriptions)
					self.syncTaggings(account, subscriptions)
				}

				self.refreshProgress.completeTask()
				completion(.success(()))
		
				
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func syncFeeds(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing feeds with %ld subscriptions.", subscriptions.count)
		
		let subFeedIds = subscriptions.map { String($0.feedID) }
		
		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelWebFeeds {
					if !subFeedIds.contains(feed.webFeedID) {
						folder.removeWebFeed(feed)
					}
				}
			}
		}
		
		for feed in account.topLevelWebFeeds {
			if !subFeedIds.contains(feed.webFeedID) {
				account.removeWebFeed(feed)
			}
		}
		
		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in
			
			let subFeedId = String(subscription.feedID)
			if let feed = account.existingWebFeed(withWebFeedID: subFeedId) {
				feed.name = subscription.name
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createWebFeed(with: subscription.name, url: subscription.url, webFeedID: subFeedId, homePageURL: subscription.homePageURL)
				feed.iconURL = subscription.iconURL
				feed.subscriptionID = String(subscription.feedID)
				account.addWebFeed(feed)
			}
			
		}
		
	}

	func syncTaggings(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing taggings with %ld subscriptions.", subscriptions.count)
		
		// Set up some structures to make syncing easier
		let folderDict: [String: Folder] = {
			if let folders = account.folders {
				return Dictionary(uniqueKeysWithValues: folders.map { ($0.name ?? "", $0) } )
			} else {
				return [String: Folder]()
			}
		}()

		let taggingsDict = subscriptions.reduce([String: [ReaderAPISubscription]]()) { (dict, subscription) in
			var taggedFeeds = dict
			
			// For each category that this feed belongs to, add the feed to that name in the dict
			subscription.categories.forEach({ (category) in
				let categoryName = category.categoryLabel.replacingOccurrences(of: "user/-/label/", with: "")
				
				if var taggedFeed = taggedFeeds[categoryName] {
					taggedFeed.append(subscription)
					taggedFeeds[categoryName] = taggedFeed
				} else {
					taggedFeeds[categoryName] = [subscription]
				}
			})
			
			return taggedFeeds
		}

		// Sync the folders
		for (folderName, groupedTaggings) in taggingsDict {
			
			guard let folder = folderDict[folderName] else { return }
			
			let taggingFeedIDs = groupedTaggings.map { String($0.feedID) }
			
			// Move any feeds not in the folder to the account
			for feed in folder.topLevelWebFeeds {
				if !taggingFeedIDs.contains(feed.webFeedID) {
					folder.removeWebFeed(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addWebFeed(feed)
				}
			}
			
			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelWebFeeds.map { $0.webFeedID }
			
			for subscription in groupedTaggings {
				let taggingFeedID = String(subscription.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingWebFeed(withWebFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: String(subscription.feedID))
					folder.addWebFeed(feed)
				}
			}
			
		}
		
		let taggedFeedIDs = Set(subscriptions.map { String($0.feedID) })
		
		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelWebFeeds {
			if taggedFeedIDs.contains(feed.webFeedID) {
				account.removeWebFeed(feed)
			}
		}

	}
	
	func sendArticleStatuses(_ statuses: [SyncStatus],
							 apiCall: ([Int], @escaping (Result<Void, Error>) -> Void) -> Void,
							 completion: @escaping (() -> Void)) {
		
		guard !statuses.isEmpty else {
			completion()
			return
		}
		
		let group = DispatchGroup()
		
		let articleIDs = statuses.compactMap { Int($0.articleID) }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {
			
			group.enter()
			apiCall(articleIDGroup) { result in
				switch result {
				case .success:
					self.database.deleteSelectedForProcessing(articleIDGroup.map { String($0) } )
					group.leave()
				case .failure(let error):
					os_log(.error, log: self.log, "Article status sync call failed: %@.", error.localizedDescription)
					self.database.resetSelectedForProcessing(articleIDGroup.map { String($0) } )
					group.leave()
				}
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			completion()
		}
		
	}
	
	
	
	func clearFolderRelationship(for feed: WebFeed, withFolderName folderName: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = nil
			feed.folderRelationship = folderRelationship
		}
	}
	
	func saveFolderRelationship(for feed: WebFeed, withFolderName folderName: String, id: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = id
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderName: id]
		}
	}

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [ReaderAPISubscriptionChoice], completion: @escaping (Result<WebFeed, Error>) -> Void) {
		
		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.UserEntered : FeedSpecifier.Source.HTMLLink
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			if let bestSubscription = choices.filter({ bestSpecifier.urlString == $0.url }).first {
				createWebFeed(for: account, url: bestSubscription.url, name: name, container: container, completion: completion)
			} else {
				DispatchQueue.main.async {
					completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
				}
			}
		} else {
			DispatchQueue.main.async {
				completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			}
		}
		
	}
	
	func createFeed( account: Account, subscription sub: ReaderAPISubscription, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		
		DispatchQueue.main.async {
			
			let feed = account.createWebFeed(with: sub.name, url: sub.url, webFeedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.subscriptionID = String(sub.feedID)
			
			account.addWebFeed(feed, to: container) { result in
				switch result {
				case .success:
					if let name = name {
						account.renameWebFeed(feed, to: name) { result in
							switch result {
							case .success:
								self.initialFeedDownload(account: account, feed: feed, completion: completion)
							case .failure(let error):
								completion(.failure(error))
							}
						}
					} else {
						self.initialFeedDownload(account: account, feed: feed, completion: completion)
					}
				case .failure(let error):
					completion(.failure(error))
				}
			}
			
		}
		
	}

	func initialFeedDownload( account: Account, feed: WebFeed, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		
		// Download the initial articles
		self.caller.retrieveEntries(webFeedID: feed.webFeedID) { result in
			
			switch result {
			case .success(let (entries, page)):
				
				self.processEntries(account: account, entries: entries) {
					self.refreshArticleStatus(for: account) { _ in
						self.refreshArticles(account, page: page) {
							self.refreshMissingArticles(account) {
								DispatchQueue.main.async {
									completion(.success(feed))
								}
							}
						}
					}
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
 
	}
	
	func refreshArticles(_ account: Account, completion: @escaping (() -> Void)) {

		os_log(.debug, log: log, "Refreshing articles...")
		
		caller.retrieveEntries() { result in
			
			switch result {
			case .success(let (entries, page, lastPageNumber)):
				
				if let last = lastPageNumber {
					self.refreshProgress.addToNumberOfTasksAndRemaining(last - 1)
				}
				
				self.processEntries(account: account, entries: entries) {
					
					self.refreshProgress.completeTask()
					self.refreshArticles(account, page: page) {
						os_log(.debug, log: self.log, "Done refreshing articles.")
						completion()
					}
					
				}

			case .failure(let error):
				os_log(.error, log: self.log, "Refresh articles failed: %@.", error.localizedDescription)
				completion()
			}
			
		}
		
	}
	
	func refreshMissingArticles(_ account: Account, completion: @escaping VoidCompletionBlock) {
		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { articleIDsResult in

			func process(_ fetchedArticleIDs: Set<String>) {
				os_log(.debug, log: self.log, "Refreshing missing articles...")
				let group = DispatchGroup()

				let articleIDs = Array(fetchedArticleIDs)
				let chunkedArticleIDs = articleIDs.chunked(into: 100)

				for chunk in chunkedArticleIDs {
					group.enter()
					self.caller.retrieveEntries(articleIDs: chunk) { result in

						switch result {
						case .success(let entries):
							self.processEntries(account: account, entries: entries) {
								group.leave()
							}

						case .failure(let error):
							os_log(.error, log: self.log, "Refresh missing articles failed: %@.", error.localizedDescription)
							group.leave()
						}
					}
				}

				group.notify(queue: DispatchQueue.main) {
					self.refreshProgress.completeTask()
					os_log(.debug, log: self.log, "Done refreshing missing articles.")
					completion()
				}
			}

			switch articleIDsResult {
			case .success(let articleIDs):
				process(articleIDs)
			case .failure:
				self.refreshProgress.completeTask()
				completion()
			}
		}
	}

	func refreshArticles(_ account: Account, page: String?, completion: @escaping (() -> Void)) {
		
		guard let page = page else {
			completion()
			return
		}
		
		caller.retrieveEntries(page: page) { result in
			
			switch result {
			case .success(let (entries, nextPage)):
				
				self.processEntries(account: account, entries: entries) {
					self.refreshProgress.completeTask()
					self.refreshArticles(account, page: nextPage, completion: completion)
				}
				
			case .failure(let error):
				os_log(.error, log: self.log, "Refresh articles for additional pages failed: %@.", error.localizedDescription)
				completion()
			}
			
		}
		
	}
	
	func processEntries(account: Account, entries: [ReaderAPIEntry]?, completion: @escaping VoidCompletionBlock) {
		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let webFeedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
		account.update(webFeedIDsAndItems: webFeedIDsAndItems, defaultRead: true) { _ in
			completion()
		}
	}
	
	func mapEntriesToParsedItems(account: Account, entries: [ReaderAPIEntry]?) -> Set<ParsedItem> {
		
		guard let entries = entries else {
			return Set<ParsedItem>()
		}
		
		let parsedItems: [ParsedItem] = entries.map { entry in
			// let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			// let feed = account.idToFeedDictionary[entry.origin.streamId!]! // TODO clean this up
			
			return ParsedItem(syncServiceID: entry.uniqueID(), uniqueID: entry.uniqueID(), feedURL: entry.origin.streamId!, url: nil, externalURL: entry.alternates.first?.url, title: entry.title, contentHTML: entry.summary.content, contentText: nil, summary: entry.summary.content, imageURL: nil, bannerImageURL: nil, datePublished: entry.parseDatePublished(), dateModified: nil, authors: nil, tags: nil, attachments: nil)
		}
		
		return Set(parsedItems)
		
	}
	
	func syncArticleReadState(account: Account, articleIDs: [Int]?) {
		guard let articleIDs = articleIDs else {
			return
		}

		let feedbinUnreadArticleIDs = Set(articleIDs.map { String($0) } )
		account.fetchUnreadArticleIDs { articleIDsResult in
			guard let currentUnreadArticleIDs = try? articleIDsResult.get() else {
				return
			}

			// Mark articles as unread
			let deltaUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
			account.markAsUnread(deltaUnreadArticleIDs)

			// Mark articles as read
			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(feedbinUnreadArticleIDs)
			account.markAsRead(deltaReadArticleIDs)
		}
	}
	
	func syncArticleStarredState(account: Account, articleIDs: [Int]?) {
		guard let articleIDs = articleIDs else {
			return
		}

		let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) } )
		account.fetchStarredArticleIDs { articleIDsResult in
			guard let currentStarredArticleIDs = try? articleIDsResult.get() else {
				return
			}

			// Mark articles as starred
			let deltaStarredArticleIDs = feedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
			account.markAsStarred(deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(feedbinStarredArticleIDs)
			account.markAsUnstarred(deltaUnstarredArticleIDs)
		}
	}



	func deleteTagging(for account: Account, with feed: WebFeed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = container as? Folder, let feedName = feed.subscriptionID {
			caller.deleteTagging(subscriptionID: feedName, tagName: folder.name ?? "") { result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						folder.removeWebFeed(feed)
						account.addFeedIfNotInAnyFolder(feed)
						completion(.success(()))
					}
				case .failure(let error):
					DispatchQueue.main.async {
						let wrappedError = AccountError.wrappedError(error: error, account: account)
						completion(.failure(wrappedError))
					}
				}
			}
		} else {
			if let account = container as? Account {
				account.removeWebFeed(feed)
			}
			completion(.success(()))
		}
		
	}

	func deleteSubscription(for account: Account, with feed: WebFeed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		// This error should never happen
		guard let subscriptionID = feed.subscriptionID else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
			return
		}
		
		caller.deleteSubscription(subscriptionID: subscriptionID) { result in
			switch result {
			case .success:
				DispatchQueue.main.async {
					account.removeWebFeed(feed)
					if let folders = account.folders {
						for folder in folders {
							folder.removeWebFeed(feed)
						}
					}
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
	
}
