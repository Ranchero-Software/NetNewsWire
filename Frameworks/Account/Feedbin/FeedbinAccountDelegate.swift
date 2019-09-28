//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
import RSCore
#endif
import Articles
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os.log

public enum FeedbinAccountDelegateError: String, Error {
	case invalidParameter = "There was an invalid parameter passed."
}

final class FeedbinAccountDelegate: AccountDelegate {

	private let database: SyncDatabase
	
	private let caller: FeedbinAPICaller
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feedbin")

	let supportsSubFolders = false
	let usesTags = true
	let server: String? = "api.feedbin.com"
	var opmlImportInProgress = false
	
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
			
			caller = FeedbinAPICaller(transport: transport!)
			
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
			
			caller = FeedbinAPICaller(transport: URLSession(configuration: sessionConfiguration))
			
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
		
		var fileData: Data?
		
		do {
			fileData = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}
		
		guard let opmlData = fileData else {
			completion(.success(()))
			return
		}
		
		os_log(.debug, log: log, "Begin importing OPML...")
		opmlImportInProgress = true
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		
		caller.importOPML(opmlData: opmlData) { result in
			switch result {
			case .success(let importResult):
				if importResult.complete {
					os_log(.debug, log: self.log, "Import OPML done.")
					self.refreshProgress.completeTask()
					self.opmlImportInProgress = false
					DispatchQueue.main.async {
						completion(.success(()))
					}
				} else {
					self.checkImportResult(opmlImportResultID: importResult.importResultID, completion: completion)
				}
			case .failure(let error):
				os_log(.debug, log: self.log, "Import OPML failed.")
				self.refreshProgress.completeTask()
				self.opmlImportInProgress = false
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}
		
	}
	
	func addFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		if let folder = account.ensureFolder(with: name) {
			completion(.success(folder))
		} else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		guard folder.hasAtLeastOneFeed() else {
			folder.name = name
			return
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.renameTag(oldName: folder.name ?? "", newName: name) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					self.renameFolderRelationship(for: account, fromName: folder.name ?? "", toName: name)
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
		
		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.removeFolder(folder)
			completion(.success(()))
			return
		}
		
		let group = DispatchGroup()
		
		for feed in folder.topLevelFeeds {
			
			if feed.folderRelationship?.count ?? 0 > 1 {
				
				if let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteTagging(taggingID: feedTaggingID) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								self.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
							}
						case .failure(let error):
							os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
						}
					}
				}
				
			} else {
				
				if let subscriptionID = feed.subscriptionID {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteSubscription(subscriptionID: subscriptionID) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								account.clearFeedMetadata(feed)
							}
						case .failure(let error):
							os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
						}
					}
					
				}
				
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			account.removeFolder(folder)
			completion(.success(()))
		}
		
	}
	
	func createFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.createSubscription(url: url) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let subResult):
				switch subResult {
				case .created(let subscription):
					self.createFeed(account: account, subscription: subscription, name: name, container: container, completion: completion)
				case .multipleChoice(let choices):
					self.decideBestFeedChoice(account: account, url: url, name: name, container: container, choices: choices, completion: completion)
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

	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if feed.folderRelationship?.count ?? 0 > 1 {
			deleteTagging(for: account, with: feed, from: container, completion: completion)
		} else {
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
		
		if let folder = container as? Folder, let feedID = Int(feed.feedID) {
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.createTagging(feedID: feedID, name: folder.name ?? "") { result in
				self.refreshProgress.completeTask()
				switch result {
				case .success(let taggingID):
					DispatchQueue.main.async {
						self.saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
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
		
		group.notify(queue: DispatchQueue.main) {
			account.addFolder(folder)
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
		credentials = try? account.retrieveBasicCredentials()
		accountMetadata = account.metadata
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, completion: @escaping (Result<Bool, Error>) -> Void) {
		
		let caller = FeedbinAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			DispatchQueue.main.async {
				completion(result)
			}
		}
		
	}
	
}

// MARK: Private

private extension FeedbinAccountDelegate {
	
	func checkImportResult(opmlImportResultID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
		
		DispatchQueue.main.async {
			
			Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { timer in
				
				os_log(.debug, log: self.log, "Checking status of OPML import...")
				
				self.caller.retrieveOPMLImportResult(importID: opmlImportResultID) { result in
					switch result {
					case .success(let importResult):
						if let result = importResult, result.complete {
							os_log(.debug, log: self.log, "Checking status of OPML import successfully completed.")
							timer.invalidate()
							self.refreshProgress.completeTask()
							self.opmlImportInProgress = false
							DispatchQueue.main.async {
								completion(.success(()))
							}
						}
					case .failure(let error):
						os_log(.debug, log: self.log, "Import OPML check failed.")
						timer.invalidate()
						self.refreshProgress.completeTask()
						self.opmlImportInProgress = false
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
				
			}
			
		}
		
	}
	
	func refreshAccount(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveTags { result in
			switch result {
			case .success(let tags):
				
				self.refreshProgress.completeTask()
				self.caller.retrieveSubscriptions { result in
					switch result {
					case .success(let subscriptions):
						
						self.refreshProgress.completeTask()
						self.forceExpireFolderFeedRelationship(account, tags)
						self.caller.retrieveTaggings { result in
							switch result {
							case .success(let taggings):
								
								self.refreshProgress.completeTask()
								self.caller.retrieveIcons { result in
									switch result {
									case .success(let icons):

										BatchUpdate.shared.perform {
											self.syncFolders(account, tags)
											self.syncFeeds(account, subscriptions)
											self.syncFeedFolderRelationship(account, taggings)
											self.syncFavicons(account, icons)
										}

										self.refreshProgress.completeTask()
										completion(.success(()))
										
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

	// This function can be deleted if Feedbin updates their taggings.json service to
	// show a change when a tag is renamed.
	func forceExpireFolderFeedRelationship(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }

		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Feedbin has a tag that we don't have a folder for.  We might not get a new
		// taggings response for it if it is a folder rename.  Force expire the tagging
		// so that we will for sure get the new tagging information.
		tags.forEach { tag in
			if !folderNames.contains(tag.name) {
				accountMetadata?.conditionalGetInfo[FeedbinAPICaller.ConditionalGetKeys.taggings] = nil
			}
		}

	}
	
	func syncFolders(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing folders with %ld tags.", tags.count)

		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
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

		// Make any folders Feedbin has, but we don't
		tagNames.forEach { tagName in
			if !folderNames.contains(tagName) {
				_ = account.ensureFolder(with: tagName)
			}
		}
		
	}
	
	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {
		
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
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
				feed.subscriptionID = String(subscription.subscriptionID)
			} else {
				let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: subFeedId, homePageURL: subscription.homePageURL)
				feed.subscriptionID = String(subscription.subscriptionID)
				account.addFeed(feed)
			}
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ taggings: [FeedbinTagging]?) {
		
		guard let taggings = taggings else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing taggings with %ld taggings.", taggings.count)
		
		// Set up some structures to make syncing easier
		let folderDict: [String: Folder] = {
			if let folders = account.folders {
				return Dictionary(uniqueKeysWithValues: folders.map { ($0.name ?? "", $0) } )
			} else {
				return [String: Folder]()
			}
		}()

		let taggingsDict = taggings.reduce([String: [FeedbinTagging]]()) { (dict, tagging) in
			var taggedFeeds = dict
			if var taggedFeed = taggedFeeds[tagging.name] {
				taggedFeed.append(tagging)
				taggedFeeds[tagging.name] = taggedFeed
			} else {
				taggedFeeds[tagging.name] = [tagging]
			}
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
			
			for tagging in groupedTaggings {
				let taggingFeedID = String(tagging.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: String(tagging.taggingID))
					folder.addFeed(feed)
				}
			}
			
		}
		
		let taggedFeedIDs = Set(taggings.map { String($0.feedID) })
		
		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
			}
		}
	}
	
	func syncFavicons(_ account: Account, _ icons: [FeedbinIcon]?) {
		
		guard let icons = icons else { return }
		
		os_log(.debug, log: log, "Syncing favicons with %ld icons.", icons.count)
		
		let iconDict = Dictionary(uniqueKeysWithValues: icons.map { ($0.host, $0.url) } )
		
		for feed in account.flattenedFeeds() {
			for (key, value) in iconDict {
				if feed.homePageURL?.contains(key) ?? false {
					feed.faviconURL = value
					break
				}
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
	
	func renameFolderRelationship(for account: Account, fromName: String, toName: String) {
		for feed in account.flattenedFeeds() {
			if var folderRelationship = feed.folderRelationship {
				let relationship = folderRelationship[fromName]
				folderRelationship[fromName] = nil
				folderRelationship[toName] = relationship
				feed.folderRelationship = folderRelationship
			}
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

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [FeedbinSubscriptionChoice], completion: @escaping (Result<Feed, Error>) -> Void) {
		
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
					completion(.failure(FeedbinAccountDelegateError.invalidParameter))
				}
			}
		} else {
			DispatchQueue.main.async {
				completion(.failure(FeedbinAccountDelegateError.invalidParameter))
			}
		}
		
	}
	
	func createFeed( account: Account, subscription sub: FeedbinSubscription, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		

		DispatchQueue.main.async {
			
			let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.subscriptionID = String(sub.subscriptionID)
		
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

		// refreshArticles is being reused and will clear one of the tasks for us
		refreshProgress.addToNumberOfTasksAndRemaining(4)

		// Download the initial articles
		self.caller.retrieveEntries(feedID: feed.feedID) { result in
			self.refreshProgress.completeTask()
			
			switch result {
			case .success(let (entries, page)):
				
				self.processEntries(account: account, entries: entries) {
					self.refreshArticleStatus(for: account) {
						self.refreshArticles(account, page: page) {
							self.refreshProgress.completeTask()
							self.refreshMissingArticles(account) {
								self.refreshProgress.completeTask()
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
	
	func processEntries(account: Account, entries: [FeedbinEntry]?, completion: @escaping (() -> Void)) {
		
		let parsedItems = mapEntriesToParsedItems(entries: entries)
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
	
	func mapEntriesToParsedItems(entries: [FeedbinEntry]?) -> Set<ParsedItem> {
		
		guard let entries = entries else {
			return Set<ParsedItem>()
		}
		
		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			return ParsedItem(syncServiceID: String(entry.articleID), uniqueID: String(entry.articleID), feedURL: String(entry.feedID), url: nil, externalURL: entry.url, title: entry.title, contentHTML: entry.contentHTML, contentText: nil, summary: entry.summary, imageURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: nil)
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
		
		if let folder = container as? Folder, let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.deleteTagging(taggingID: feedTaggingID) { result in
				self.refreshProgress.completeTask()
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
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.deleteSubscription(subscriptionID: subscriptionID) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					account.clearFeedMetadata(feed)
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
