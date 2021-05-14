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
import Secrets

public enum ReaderAPIAccountDelegateError: LocalizedError {
	case unknown
	case invalidParameter
	case invalidResponse
	case urlNotFound
	
	public var errorDescription: String? {
		switch self {
		case .unknown:
			return NSLocalizedString("An unexpected error occurred.", comment: "An unexpected error occurred.")
		case .invalidParameter:
			return NSLocalizedString("An invalid parameter was passed.", comment: "An invalid parameter was passed.")
		case .invalidResponse:
			return NSLocalizedString("There was an invalid response from the server.", comment: "There was an invalid response from the server.")
		case .urlNotFound:
			return NSLocalizedString("The API URL wasn't found.", comment: "The API URL wasn't found.")
		}
	}
}

final class ReaderAPIAccountDelegate: AccountDelegate {
	
	private let variant: ReaderAPIVariant
	
	private let database: SyncDatabase
	
	private let caller: ReaderAPICaller
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ReaderAPI")

	var behaviors: AccountBehaviors {
		var behaviors: AccountBehaviors = [.disallowOPMLImports, .disallowFeedInMultipleFolders]
		if variant == .freshRSS {
			behaviors.append(.disallowFeedInRootFolder)
		}
		return behaviors
	}

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

	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	init(dataFolder: String, transport: Transport?, variant: ReaderAPIVariant) {
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
		
		caller.variant = variant
		self.variant = variant
	}
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		completion()
	}
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(6)
		
		refreshAccount(account) { result in
			switch result {
			case .success():
				self.sendArticleStatus(for: account) { _ in
					self.refreshProgress.completeTask()
					self.caller.retrieveItemIDs(type: .allForAccount) { result in
						self.refreshProgress.completeTask()
						switch result {
						case .success(let articleIDs):
							account.markAsRead(Set(articleIDs)) { _ in
								self.refreshArticleStatus(for: account) { _ in
									self.refreshProgress.completeTask()
									self.refreshMissingArticles(account) {
										self.refreshProgress.clear()
										DispatchQueue.main.async {
											completion(.success(()))
										}
									}
								}
							}
						case .failure(let error):
							completion(.failure(error))
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

	func syncArticleStatus(for account: Account, completion: ((Result<Void, Error>) -> Void)? = nil) {
		guard variant != .inoreader else {
			completion?(.success(()))
			return
		}
		
		sendArticleStatus(for: account) { result in
			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						completion?(.success(()))
					case .failure(let error):
						completion?(.failure(error))
					}
				}
			case .failure(let error):
				completion?(.failure(error))
			}
		}
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		os_log(.debug, log: log, "Sending article statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				let createUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false }
				let deleteUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true }
				let createStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true }
				let deleteStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false }

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
		var errorOccurred = false

		group.enter()
		caller.retrieveItemIDs(type: .unread) { result in
			switch result {
			case .success(let articleIDs):
				self.syncArticleReadState(account: account, articleIDs: articleIDs) {
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				os_log(.info, log: self.log, "Retrieving unread entries failed: %@.", error.localizedDescription)
				group.leave()
			}
			
		}
		
		group.enter()
		caller.retrieveItemIDs(type: .starred) { result in
			switch result {
			case .success(let articleIDs):
				self.syncArticleStarredState(account: account, articleIDs: articleIDs) {
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				os_log(.info, log: self.log, "Retrieving starred entries failed: %@.", error.localizedDescription)
				group.leave()
			}

		}
		
		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			if errorOccurred {
				completion(.failure(ReaderAPIAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}
	
	func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
	}
	
	func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		if let folder = account.ensureFolder(with: name) {
			completion(.success(folder))
		} else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
		}
	}
	
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.renameTag(oldName: folder.name ?? "", newName: name) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					folder.externalID = "user/-/label/\(name)"
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
			
			if feed.folderRelationship?.count ?? 0 > 1 {
				
				if let feedExternalID = feed.externalID {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteTagging(subscriptionID: feedExternalID, tagName: folder.nameForDisplay) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								self.clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
							}
						case .failure(let error):
							os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
						}
					}
				}
				
			} else {
				
				if let subscriptionID = feed.externalID {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteSubscription(subscriptionID: subscriptionID) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								account.clearWebFeedMetadata(feed)
							}
						case .failure(let error):
							os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
						}
					}
					
				}
				
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			if self.variant == .theOldReader {
				account.removeFolder(folder)
				completion(.success(()))
			} else {
				self.caller.deleteTag(folder: folder) { result in
					switch result {
					case .success:
						account.removeFolder(folder)
						completion(.success(()))
					case .failure(let error):
						completion(.failure(error))
					}
				}
			}
		}
		
	}
	
	func createWebFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		guard let url = URL(string: url) else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			return
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(2)
		
		FeedFinder.find(url: url) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success(let feedSpecifiers):
				let feedSpecifiers = feedSpecifiers.filter { !$0.urlString.contains("json") }
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers) else {
					self.refreshProgress.clear()
					completion(.failure(AccountError.createErrorNotFound))
					return
				}

				self.caller.createSubscription(url: bestFeedSpecifier.urlString, name: name, folder: container as? Folder) { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success(let subResult):
						switch subResult {
						case .created(let subscription):
							self.createFeed(account: account, subscription: subscription, name: name, container: container, completion: completion)
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
			case .failure:
				self.refreshProgress.clear()
				completion(.failure(AccountError.createErrorNotFound))
			}
			
		}
		
	}
	
	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			return
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.renameSubscription(subscriptionID: subscriptionID, newName: name) { result in
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
	
	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let subscriptionID = feed.externalID else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			return
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.deleteSubscription(subscriptionID: subscriptionID) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					account.clearWebFeedMetadata(feed)
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
		if let folder = container as? Folder, let feedExternalID = feed.externalID {
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.createTagging(subscriptionID: feedExternalID, tagName: folder.name ?? "") { result in
				self.refreshProgress.completeTask()
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.saveFolderRelationship(for: feed, folderExternalID: folder.externalID, feedExternalID: feedExternalID)
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
			createWebFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true) { result in
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
		
		for feed in folder.topLevelWebFeeds {
			
			folder.topLevelWebFeeds.remove(feed)
			
			group.enter()
			restoreWebFeed(for: account, feed: feed, container: folder) { result in
				group.leave()
				switch result {
				case .success:
					break
				case .failure(let error):
					os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
				}
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			account.addFolder(folder)
			completion(.success(()))
		}
		
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
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
						completion(.success(()))
					}
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
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
				self.refreshProgress.completeTask()
				self.caller.retrieveSubscriptions { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success(let subscriptions):
						BatchUpdate.shared.perform {
							self.syncFolders(account, tags)
							self.syncFeeds(account, subscriptions)
							self.syncFeedFolderRelationship(account, subscriptions)
						}
						completion(.success(()))
					case .failure(let error):
						completion(.failure(error))
					}
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func syncFolders(_ account: Account, _ tags: [ReaderAPITag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)
		
		let folderTags: [ReaderAPITag]
		if variant == .inoreader {
			folderTags = tags.filter{ $0.type == "folder" }
		} else {
			folderTags = tags.filter{ $0.tagID.contains("/label/") }
		}
		
		guard !folderTags.isEmpty else { return }
		
		os_log(.debug, log: log, "Syncing folders with %ld tags.", folderTags.count)

		let readerFolderExternalIDs = folderTags.compactMap { $0.tagID }

		// Delete any folders not at Reader
		if let folders = account.folders {
			folders.forEach { folder in
				if !readerFolderExternalIDs.contains(folder.externalID ?? "") {
					for feed in folder.topLevelWebFeeds {
						account.addWebFeed(feed)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					}
					account.removeFolder(folder)
				}
			}
		}
		
		let folderExternalIDs: [String] =  {
			if let folders = account.folders {
				return folders.compactMap { $0.externalID }
			} else {
				return [String]()
			}
		}()

		// Make any folders Reader has, but we don't
		folderTags.forEach { tag in
			if !folderExternalIDs.contains(tag.tagID) {
				let folder = account.ensureFolder(with: tag.folderName ?? "None")
				folder?.externalID = tag.tagID
			}
		}
		
	}
	
	func syncFeeds(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing feeds with %ld subscriptions.", subscriptions.count)
		
		let subFeedIds = subscriptions.map { $0.feedID }
		
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
				account.clearWebFeedMetadata(feed)
				account.removeWebFeed(feed)
			}
		}
		
		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in
			
			if let feed = account.existingWebFeed(withWebFeedID: subscription.feedID) {
				feed.name = subscription.name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createWebFeed(with: subscription.name, url: subscription.url, webFeedID: subscription.feedID, homePageURL: subscription.homePageURL)
				feed.externalID = subscription.feedID
				account.addWebFeed(feed)
			}
			
		}
		
	}

	func syncFeedFolderRelationship(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)
		os_log(.debug, log: log, "Syncing taggings with %ld subscriptions.", subscriptions.count)
		
		// Set up some structures to make syncing easier
		let folderDict = externalIDToFolderDictionary(with: account.folders)
		let taggingsDict = subscriptions.reduce([String: [ReaderAPISubscription]]()) { (dict, subscription) in
			var taggedFeeds = dict
			
			subscription.categories.forEach({ (category) in
				if var taggedFeed = taggedFeeds[category.categoryId] {
					taggedFeed.append(subscription)
					taggedFeeds[category.categoryId] = taggedFeed
				} else {
					taggedFeeds[category.categoryId] = [subscription]
				}
			})
			
			return taggedFeeds
		}
		
		// Sync the folders
		for (folderExternalID, groupedTaggings) in taggingsDict {
			guard let folder = folderDict[folderExternalID] else { return }
			let taggingFeedIDs = groupedTaggings.map { $0.feedID }
			
			// Move any feeds not in the folder to the account
			for feed in folder.topLevelWebFeeds {
				if !taggingFeedIDs.contains(feed.webFeedID) {
					folder.removeWebFeed(feed)
					clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					account.addWebFeed(feed)
				}
			}
			
			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelWebFeeds.map { $0.webFeedID }
			
			for subscription in groupedTaggings {
				let taggingFeedID = subscription.feedID
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingWebFeed(withWebFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, folderExternalID: folderExternalID, feedExternalID: subscription.feedID)
					folder.addWebFeed(feed)
				}
			}
			
		}
	
		let taggedFeedIDs = Set(subscriptions.filter({ !$0.categories.isEmpty }).map { String($0.feedID) })
		
		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelWebFeeds {
			if taggedFeedIDs.contains(feed.webFeedID) {
				account.removeWebFeed(feed)
			}
		}
	}
	
	func externalIDToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()
		
		for folder in folders {
			if let externalID = folder.externalID, d[externalID] == nil {
				d[externalID] = folder
			}
		}
		
		return d
	}

	func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([String], @escaping (Result<Void, Error>) -> Void) -> Void, completion: @escaping (() -> Void)) {
		guard !statuses.isEmpty else {
			completion()
			return
		}
		
		let group = DispatchGroup()
		
		let articleIDs = statuses.compactMap { $0.articleID }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {
			
			group.enter()
			apiCall(articleIDGroup) { result in
				switch result {
				case .success:
					self.database.deleteSelectedForProcessing(articleIDGroup.map { $0 } )
					group.leave()
				case .failure(let error):
					os_log(.error, log: self.log, "Article status sync call failed: %@.", error.localizedDescription)
					self.database.resetSelectedForProcessing(articleIDGroup.map { $0 } )
					group.leave()
				}
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			completion()
		}
		
	}
	
	func clearFolderRelationship(for feed: WebFeed, folderExternalID: String?) {
		guard var folderRelationship = feed.folderRelationship, let folderExternalID = folderExternalID else { return }
		folderRelationship[folderExternalID] = nil
		feed.folderRelationship = folderRelationship
	}
	
	func saveFolderRelationship(for feed: WebFeed, folderExternalID: String?, feedExternalID: String) {
		guard let folderExternalID = folderExternalID else { return }
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderExternalID] = feedExternalID
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderExternalID: feedExternalID]
		}
	}
	
	func createFeed( account: Account, subscription sub: ReaderAPISubscription, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		
		DispatchQueue.main.async {
			
			let feed = account.createWebFeed(with: sub.name, url: sub.url, webFeedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.externalID = String(sub.feedID)
			
			account.addWebFeed(feed, to: container) { result in
				switch result {
				case .success:
					if let name = name {
						self.renameWebFeed(for: account, with: feed, to: name) { result in
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
		refreshProgress.addToNumberOfTasksAndRemaining(5)
		
		// Download the initial articles
		self.caller.retrieveItemIDs(type: .allForFeed, webFeedID: feed.webFeedID) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let articleIDs):
				account.markAsRead(Set(articleIDs)) { _ in
					self.refreshProgress.completeTask()
					self.refreshArticleStatus(for: account) { _ in
						self.refreshProgress.completeTask()
						self.refreshMissingArticles(account) {
							self.refreshProgress.clear()
							DispatchQueue.main.async {
								completion(.success(feed))
							}

						}
					}

				}
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
 
	}
	
	func refreshMissingArticles(_ account: Account, completion: @escaping VoidCompletionBlock) {
		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { articleIDsResult in

			func process(_ fetchedArticleIDs: Set<String>) {
				guard !fetchedArticleIDs.isEmpty else {
					completion()
					return
				}
				
				os_log(.debug, log: self.log, "Refreshing missing articles...")
				let group = DispatchGroup()

				let articleIDs = Array(fetchedArticleIDs)
				let chunkedArticleIDs = articleIDs.chunked(into: 150)

				self.refreshProgress.addToNumberOfTasksAndRemaining(chunkedArticleIDs.count - 1)

				for chunk in chunkedArticleIDs {
					group.enter()
					self.caller.retrieveEntries(articleIDs: chunk) { result in
						self.refreshProgress.completeTask()

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
		
		let parsedItems: [ParsedItem] = entries.compactMap { entry in
			guard let streamID = entry.origin.streamId else {
				return nil
			}
			// let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			// let feed = account.idToFeedDictionary[entry.origin.streamId!]! // TODO clean this up
			
			return ParsedItem(syncServiceID: entry.uniqueID(variant: variant),
							  uniqueID: entry.uniqueID(variant: variant),
							  feedURL: streamID,
							  url: nil,
							  externalURL: entry.alternates.first?.url,
							  title: entry.title,
							  language: nil,
							  contentHTML: entry.summary.content,
							  contentText: nil,
							  summary: entry.summary.content,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: entry.parseDatePublished(),
							  dateModified: nil,
							  authors: nil,
							  tags: nil,
							  attachments: nil)
		}
		
		return Set(parsedItems)
		
	}
	
	func syncArticleReadState(account: Account, articleIDs: [String]?, completion: @escaping (() -> Void)) {
		guard let articleIDs = articleIDs else {
			completion()
			return
		}

		database.selectPendingReadStatusArticleIDs() { result in

			func process(_ pendingArticleIDs: Set<String>) {
				let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
				
				account.fetchUnreadArticleIDs { articleIDsResult in
					guard let currentUnreadArticleIDs = try? articleIDsResult.get() else {
						return
					}

					let group = DispatchGroup()
					
					// Mark articles as unread
					let deltaUnreadArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
					group.enter()
					account.markAsUnread(deltaUnreadArticleIDs) { _ in
						group.leave()
					}

					// Mark articles as read
					let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
					group.enter()
					account.markAsRead(deltaReadArticleIDs) { _ in
						group.leave()
					}
					
					group.notify(queue: DispatchQueue.main) {
						completion()
					}
				}
			}
			
			switch result {
			case .success(let pendingArticleIDs):
				process(pendingArticleIDs)
			case .failure(let error):
				os_log(.error, log: self.log, "Sync Article Read Status failed: %@.", error.localizedDescription)
			}
			
		}
		
	}
	
	func syncArticleStarredState(account: Account, articleIDs: [String]?, completion: @escaping (() -> Void)) {
		guard let articleIDs = articleIDs else {
			completion()
			return
		}

		database.selectPendingStarredStatusArticleIDs() { result in

			func process(_ pendingArticleIDs: Set<String>) {
				let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)

				account.fetchStarredArticleIDs { articleIDsResult in
					guard let currentStarredArticleIDs = try? articleIDsResult.get() else {
						return
					}

					let group = DispatchGroup()
					
					// Mark articles as starred
					let deltaStarredArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentStarredArticleIDs)
					group.enter()
					account.markAsStarred(deltaStarredArticleIDs) { _ in
						group.leave()
					}

					// Mark articles as unstarred
					let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
					group.enter()
					account.markAsUnstarred(deltaUnstarredArticleIDs) { _ in
						group.leave()
					}

					group.notify(queue: DispatchQueue.main) {
						completion()
					}
				}
			}
			
			switch result {
			case .success(let pendingArticleIDs):
				process(pendingArticleIDs)
			case .failure(let error):
				os_log(.error, log: self.log, "Sync Article Starred Status failed: %@.", error.localizedDescription)
			}

		}
		
	}

	func deleteTagging(for account: Account, with feed: WebFeed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = container as? Folder, let feedName = feed.externalID {
			caller.deleteTagging(subscriptionID: feedName, tagName: folder.name ?? "") { result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
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
	
}
