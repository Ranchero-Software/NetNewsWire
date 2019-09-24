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
				
				self.sendArticleStatus(for: account) {
					self.refreshArticleStatus(for: account) {
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

	func sendArticleStatus(for account: Account, completion: @escaping (() -> Void)) {

		os_log(.debug, log: log, "Sending article statuses...")
		
		let syncStatuses = database.selectForProcessing()
		let createUnreadStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.read && $0.flag == false }
		let deleteUnreadStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.read && $0.flag == true }
		let createStarredStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.starred && $0.flag == true }
		let deleteStarredStatuses = syncStatuses.filter { $0.key == ArticleStatus.Key.starred && $0.flag == false }

		let group = DispatchGroup()
		
		group.enter()
		sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries) {
			group.leave()
		}
		
		group.enter()
		sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries) {
			group.leave()
		}
		
		group.enter()
		sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries) {
			group.leave()
		}
		
		group.enter()
		sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries) {
			group.leave()
		}
		
		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done sending article statuses.")
			completion()
		}
		
	}
	
	func refreshArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		
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
			completion()
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
		
		for feed in folder.topLevelFeeds {
			group.enter()
			removeFeed(for: account, with: feed, from: folder) { result in
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
	
	func createFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		
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
	
	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
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
	
	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if feed.folderRelationship?.count ?? 0 > 1 {
			deleteTagging(for: account, with: feed, from: container, completion: completion)
		} else {
			account.clearFeedMetadata(feed)
			deleteSubscription(for: account, with: feed, from: container, completion: completion)
		}
	}
	
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if from is Account {
			addFeed(for: account, with: feed, to: to, completion: completion)
		} else {
			deleteTagging(for: account, with: feed, from: from) { result in
				switch result {
				case .success:
					self.addFeed(for: account, with: feed, to: to, completion: completion)
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}
	
	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = container as? Folder, let feedName = feed.subscriptionID {
			caller.createTagging(subscriptionID: feedName, tagName: folder.name ?? "") { result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: feed.subscriptionID!)
						account.removeFeed(feed)
						folder.addFeed(feed)
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
	
	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		
		createFeed(for: account, url: feed.url, name: feed.editedName, container: container) { result in
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
		
		for feed in folder.topLevelFeeds {
			
			group.enter()
			addFeed(for: account, with: feed, to: folder) { result in
				if account.topLevelFeeds.contains(feed) {
					account.removeFeed(feed)
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
		
		if database.selectPendingCount() > 100 {
			sendArticleStatus(for: account) {}
		}
		
		return account.update(articles, statusKey: statusKey, flag: flag)
		
	}
	
	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .readerAPIKey)
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
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
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
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						folder.removeFeed(feed)
					}
				}
			}
		}
		
		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				account.removeFeed(feed)
			}
		}
		
		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in
			
			let subFeedId = String(subscription.feedID)
			if let feed = account.existingFeed(withFeedID: subFeedId) {
				feed.name = subscription.name
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: subFeedId, homePageURL: subscription.homePageURL)
				feed.iconURL = subscription.iconURL
				feed.subscriptionID = String(subscription.feedID)
				account.addFeed(feed)
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
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					folder.removeFeed(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addFeed(feed)
				}
			}
			
			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }
			
			for subscription in groupedTaggings {
				let taggingFeedID = String(subscription.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: String(subscription.feedID))
					folder.addFeed(feed)
				}
			}
			
		}
		
		let taggedFeedIDs = Set(subscriptions.map { String($0.feedID) })
		
		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
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
	
	
	
	func clearFolderRelationship(for feed: Feed, withFolderName folderName: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = nil
			feed.folderRelationship = folderRelationship
		}
	}
	
	func saveFolderRelationship(for feed: Feed, withFolderName folderName: String, id: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = id
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderName: id]
		}
	}

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [ReaderAPISubscriptionChoice], completion: @escaping (Result<Feed, Error>) -> Void) {
		
		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.UserEntered : FeedSpecifier.Source.HTMLLink
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			if let bestSubscription = choices.filter({ bestSpecifier.urlString == $0.url }).first {
				createFeed(for: account, url: bestSubscription.url, name: name, container: container, completion: completion)
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
	
	func createFeed( account: Account, subscription sub: ReaderAPISubscription, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		DispatchQueue.main.async {
			
			let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.subscriptionID = String(sub.feedID)
			
			account.addFeed(feed, to: container) { result in
				switch result {
				case .success:
					if let name = name {
						account.renameFeed(feed, to: name) { result in
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

	func initialFeedDownload( account: Account, feed: Feed, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		// Download the initial articles
		self.caller.retrieveEntries(feedID: feed.feedID) { result in
			
			switch result {
			case .success(let (entries, page)):
				
				self.processEntries(account: account, entries: entries) {
					self.refreshArticleStatus(for: account) {
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
	
	func refreshMissingArticles(_ account: Account, completion: @escaping (() -> Void)) {
		
		os_log(.debug, log: log, "Refreshing missing articles...")
		let group = DispatchGroup()

		let fetchedArticleIDs = account.fetchArticleIDsForStatusesWithoutArticles()
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
	
	func processEntries(account: Account, entries: [ReaderAPIEntry]?, completion: @escaping (() -> Void)) {
		
		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let parsedMap = Dictionary(grouping: parsedItems, by: { item in item.feedURL } )
		
		let group = DispatchGroup()
		
		for (feedID, mapItems) in parsedMap {
			
			group.enter()
			
			if let feed = account.existingFeed(withFeedID: feedID) {
				DispatchQueue.main.async {
					account.update(feed, parsedItems: Set(mapItems), defaultRead: true) {
						group.leave()
					}
				}
			} else {
				group.leave()
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
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
		let currentUnreadArticleIDs = account.fetchUnreadArticleIDs()
		
		// Mark articles as unread
		let deltaUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
		let markUnreadArticles = account.fetchArticles(.articleIDs(deltaUnreadArticleIDs))
		account.update(markUnreadArticles, statusKey: .read, flag: false)

		// Save any unread statuses for articles we haven't yet received
		let markUnreadArticleIDs = Set(markUnreadArticles.map { $0.articleID })
		let missingUnreadArticleIDs = deltaUnreadArticleIDs.subtracting(markUnreadArticleIDs)
		account.ensureStatuses(missingUnreadArticleIDs, true, .read, false)

		// Mark articles as read
		let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(feedbinUnreadArticleIDs)
		let markReadArticles = account.fetchArticles(.articleIDs(deltaReadArticleIDs))
		account.update(markReadArticles, statusKey: .read, flag: true)

		// Save any read statuses for articles we haven't yet received
		let markReadArticleIDs = Set(markReadArticles.map { $0.articleID })
		let missingReadArticleIDs = deltaReadArticleIDs.subtracting(markReadArticleIDs)
		account.ensureStatuses(missingReadArticleIDs, true, .read, true)

	}
	
	func syncArticleStarredState(account: Account, articleIDs: [Int]?) {
		guard let articleIDs = articleIDs else {
			return
		}

		let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) } )
		let currentStarredArticleIDs = account.fetchStarredArticleIDs()
		
		// Mark articles as starred
		let deltaStarredArticleIDs = feedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
		let markStarredArticles = account.fetchArticles(.articleIDs(deltaStarredArticleIDs))
		account.update(markStarredArticles, statusKey: .starred, flag: true)

		// Save any starred statuses for articles we haven't yet received
		let markStarredArticleIDs = Set(markStarredArticles.map { $0.articleID })
		let missingStarredArticleIDs = deltaStarredArticleIDs.subtracting(markStarredArticleIDs)
		account.ensureStatuses(missingStarredArticleIDs, true, .starred, true)

		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(feedbinStarredArticleIDs)
		let markUnstarredArticles = account.fetchArticles(.articleIDs(deltaUnstarredArticleIDs))
		account.update(markUnstarredArticles, statusKey: .starred, flag: false)

		// Save any unstarred statuses for articles we haven't yet received
		let markUnstarredArticleIDs = Set(markUnstarredArticles.map { $0.articleID })
		let missingUnstarredArticleIDs = deltaUnstarredArticleIDs.subtracting(markUnstarredArticleIDs)
		account.ensureStatuses(missingUnstarredArticleIDs, true, .starred, false)
	}



	func deleteTagging(for account: Account, with feed: Feed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = container as? Folder, let feedName = feed.subscriptionID {
			caller.deleteTagging(subscriptionID: feedName, tagName: folder.name ?? "") { result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						folder.removeFeed(feed)
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
				account.removeFeed(feed)
			}
			completion(.success(()))
		}
		
	}

	func deleteSubscription(for account: Account, with feed: Feed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		// This error should never happen
		guard let subscriptionID = feed.subscriptionID else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
			return
		}
		
		caller.deleteSubscription(subscriptionID: subscriptionID) { result in
			switch result {
			case .success:
				DispatchQueue.main.async {
					account.removeFeed(feed)
					if let folders = account.folders {
						for folder in folders {
							folder.removeFeed(feed)
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
