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
import RSCore
import RSParser
import RSWeb
import os.log

public enum FeedbinAccountDelegateError: String, Error {
	case invalidParameter = "There was an invalid parameter passed."
}

final class FeedbinAccountDelegate: AccountDelegate {

	private let caller: FeedbinAPICaller
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feedbin")

	let supportsSubFolders = false
	let server: String? = "api.feedbin.com"
	
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	init(transport: Transport?) {
		
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
	
	func refreshAll(for account: Account, completion: (() -> Void)? = nil) {
		
		refreshProgress.addToNumberOfTasksAndRemaining(5)
		
		refreshAccount(account) { [weak self] result in
			switch result {
			case .success():
				
				self?.refreshArticles(account) {
					self?.refreshArticleStatus(for: account) {
						completion?()
					}
				}
				
			case .failure(let error):
				DispatchQueue.main.async {
					completion?()
					self?.refreshProgress.clear()
					self?.handleError(error)
				}
			}
			
		}
		
	}

	func refreshArticleStatus(for account: Account, completion: (() -> Void)? = nil) {

		os_log(.debug, log: log, "Refreshing article statuses...")
		
		let group = DispatchGroup()
		
		group.enter()
		caller.retrieveUnreadEntries() { [weak self] result in
			switch result {
			case .success(let articleIDs):
				self?.syncArticleReadState(account: account, articleIDs: articleIDs)
				group.leave()
			case .failure(let error):
				guard let self = self else { return }
				os_log(.info, log: self.log, "Retrieving unread entries failed: %@.", error.localizedDescription)
			}
			
		}
		
		group.enter()
		caller.retrieveStarredEntries() { [weak self] result in
			switch result {
			case .success(let articleIDs):
				self?.syncArticleStarredState(account: account, articleIDs: articleIDs)
				group.leave()
			case .failure(let error):
				guard let self = self else { return }
				os_log(.info, log: self.log, "Retrieving starred entries failed: %@.", error.localizedDescription)
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) { [weak self] in
			guard let self = self else { return }
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			completion?()
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
		
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		var opmlDocument: RSOPMLDocument?
		
		do {
			opmlDocument = try RSOPMLParser.parseOPML(with: parserData)
		} catch {
			completion(.failure(error))
			return
		}
		
		guard let loadDocument = opmlDocument, let children = loadDocument.children else {
			completion(.success(()))
			return
		}
		
		importOPMLItems(account, items: children, parentFolder: nil)

		completion(.success(()))
		
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
					completion(.failure(error))
				}
			}
		}
		
	}

	func deleteFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		
		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.deleteFolder(folder)
			return
		}
		
		// After we successfully delete at Feedbin, we add all the feeds to the account to save them.  We then
		// delete the folder.  We then sync the taggings we received on the delete to remove any feeds from
		// the account that might be in another folder.
		caller.deleteTag(name: folder.name ?? "") { [weak self] result in
			switch result {
			case .success(let taggings):
				DispatchQueue.main.sync {
					BatchUpdate.shared.perform {
						for feed in folder.topLevelFeeds {
							account.addFeed(feed)
							self?.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						}
						account.deleteFolder(folder)
					}
					completion(.success(()))
				}
				self?.syncTaggings(account, taggings)
			case .failure(let error):
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
		}
		
	}
	
	func createFeed(for account: Account, url: String, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		caller.createSubscription(url: url) { [weak self] result in
			switch result {
			case .success(let subResult):
				switch subResult {
				case .created(let subscription):
					self?.createFeed(account: account, subscription: subscription, completion: completion)
				case .multipleChoice(let choices):
					self?.decideBestFeedChoice(account: account, url: url, choices: choices, completion: completion)
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
					completion(.failure(error))
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
					completion(.failure(error))
				}
			}
		}
		
	}

	func deleteFeed(for account: Account, with feed: Feed, completion: @escaping (Result<Void, Error>) -> Void) {
		
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
					completion(.failure(error))
				}
			}
		}
		
	}
	
	func addFeed(for account: Account, to container: Container, with feed: Feed, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = container as? Folder, let feedID = Int(feed.feedID) {
			caller.createTagging(feedID: feedID, name: folder.name ?? "") { [weak self] result in
				switch result {
				case .success(let taggingID):
					DispatchQueue.main.async {
						self?.saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
						folder.addFeed(feed)
						completion(.success(()))
					}
				case .failure(let error):
					DispatchQueue.main.async {
						completion(.failure(error))
					}
				}
			}
		} else {
			if let account = container as? Account {
				account.addFeed(feed)
			}
			DispatchQueue.main.async {
				completion(.success(()))
			}
		}
		
	}
	
	func removeFeed(for account: Account, from container: Container, with feed: Feed, completion: @escaping (Result<Void, Error>) -> Void) {

		if let folder = container as? Folder, let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
			caller.deleteTagging(taggingID: feedTaggingID) { result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						folder.removeFeed(feed)
						completion(.success(()))
					}
				case .failure(let error):
					DispatchQueue.main.async {
						completion(.failure(error))
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
	
	func restoreFeed(for account: Account, feed: Feed, folder: Folder?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		let editedName = feed.editedName
		
		createFeed(for: account, url: feed.url) { [weak self] result in
			switch result {
			case .success(let feed):
				self?.processRestoredFeed(for: account, feed: feed, editedName: editedName, folder: folder, completion: completion)
			case .failure(let error):
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
		}
		
	}
	
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		
		account.addFolder(folder)
		let group = DispatchGroup()
		
		for feed in folder.topLevelFeeds {
			
			group.enter()
			addFeed(for: account, to: folder, with: feed) { result in
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
	
	func handleError(_ error: Error) {
		// TODO: We should do a better job of error handling here.
		// We need to prompt for credentials if they are expired.
		#if os(macOS)
		NSApplication.shared.presentError(error)
		#else
		UIApplication.shared.presentError(error)
		#endif
	}
	
	func refreshAccount(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveTags { [weak self] result in
			switch result {
			case .success(let tags):
				BatchUpdate.shared.perform {
					self?.syncFolders(account, tags)
				}
				self?.refreshProgress.completeTask()
				self?.refreshFeeds(account, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func syncFolders(_ account: Account, _ tags: [FeedbinTag]?) {
		
		guard let tags = tags else { return }

		os_log(.debug, log: log, "Syncing folders with %ld tags.", tags.count)

		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
		if let folders = account.folders {
			folders.forEach { folder in
				if !tagNames.contains(folder.name ?? "") {
					DispatchQueue.main.sync {
						for feed in folder.topLevelFeeds {
							account.addFeed(feed)
							clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						}
						account.deleteFolder(folder)
					}
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
				DispatchQueue.main.sync {
					_ = account.ensureFolder(with: tagName)
				}
			}
		}
		
	}
	
	func refreshFeeds(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveSubscriptions { [weak self] result in
			switch result {
			case .success(let subscriptions):
				
				self?.refreshProgress.completeTask()
				self?.caller.retrieveTaggings { [weak self] result in
					switch result {
					case .success(let taggings):
						
						self?.refreshProgress.completeTask()
						self?.caller.retrieveIcons { [weak self] result in
							switch result {
							case .success(let icons):

								BatchUpdate.shared.perform {
									self?.syncFeeds(account, subscriptions)
									self?.syncTaggings(account, taggings)
									self?.syncFavicons(account, icons)
								}

								self?.refreshProgress.completeTask()
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
		
	}

	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {
		
		guard let subscriptions = subscriptions else { return }
		
		os_log(.debug, log: log, "Syncing feeds with %ld subscriptions.", subscriptions.count)
		
		let subFeedIds = subscriptions.map { String($0.feedID) }
		
		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						DispatchQueue.main.sync {
							folder.removeFeed(feed)
						}
					}
				}
			}
		}
		
		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				DispatchQueue.main.sync {
					account.removeFeed(feed)
				}
			}
		}
		
		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in
			
			let subFeedId = String(subscription.feedID)
			
			DispatchQueue.main.sync {
				if let feed = account.idToFeedDictionary[subFeedId] {
					feed.name = subscription.name
					feed.homePageURL = subscription.homePageURL
				} else {
					let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: subFeedId, homePageURL: subscription.homePageURL)
					feed.subscriptionID = String(subscription.subscriptionID)
					account.addFeed(feed)
				}
			}
			
		}
		
	}

	func syncTaggings(_ account: Account, _ taggings: [FeedbinTagging]?) {
		
		guard let taggings = taggings else { return }

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
					DispatchQueue.main.sync {
						folder.removeFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						account.addFeed(feed)
					}
				}
			}
			
			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }
			
			for tagging in groupedTaggings {
				let taggingFeedID = String(tagging.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.idToFeedDictionary[taggingFeedID] else {
						continue
					}
					DispatchQueue.main.sync {
						saveFolderRelationship(for: feed, withFolderName: folderName, id: String(tagging.taggingID))
						folder.addFeed(feed)
					}
				}
			}
			
		}
		
		let taggedFeedIDs = Set(taggings.map { String($0.feedID) })
		
		// Remove all feeds from the account container that have a tag
		DispatchQueue.main.sync {
			for feed in account.topLevelFeeds {
				if taggedFeedIDs.contains(feed.feedID) {
					account.removeFeed(feed)
				}
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
					DispatchQueue.main.sync {
						feed.faviconURL = value
					}
					break
				}
			}
		}

	}
	
	func importOPMLItems(_ account: Account, items: [RSOPMLItem], parentFolder: Folder?) {
		
		items.forEach { (item) in
			
			if let feedSpecifier = item.feedSpecifier {
				importFeedSpecifier(account, feedSpecifier: feedSpecifier, parentFolder: parentFolder)
				return
			}
			
			guard let folderName = item.titleFromAttributes else {
				// Folder doesn’t have a name, so it won’t be created, and its items will go one level up.
				if let itemChildren = item.children {
					importOPMLItems(account, items: itemChildren, parentFolder: parentFolder)
				}
				return
			}
			
			if let folder = account.ensureFolder(with: folderName) {
				if let itemChildren = item.children {
					importOPMLItems(account, items: itemChildren, parentFolder: folder)
				}
			}
			
		}
		
	}
	
	func importFeedSpecifier(_ account: Account, feedSpecifier: RSOPMLFeedSpecifier, parentFolder: Folder?) {
		
		caller.createSubscription(url: feedSpecifier.feedURL) { [weak self] result in
			
			switch result {
			case .success(let subResult):
				switch subResult {
				case .created(let sub):
					
					DispatchQueue.main.async {
						
						let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
						feed.subscriptionID = String(sub.subscriptionID)
						
						self?.importFeedSpecifierPostProcess(account: account, sub: sub, feedSpecifier: feedSpecifier, feed: feed, parentFolder: parentFolder)
						
					}
					
				default:
					break
				}
				
			case .failure(let error):
				guard let self = self else { return }
				os_log(.error, log: self.log, "Create feed on OPML import failed: %@.", error.localizedDescription)
			}
			
		}
		
	}
	
	func importFeedSpecifierPostProcess(account: Account, sub: FeedbinSubscription, feedSpecifier: RSOPMLFeedSpecifier, feed: Feed, parentFolder: Folder?) {
		
		// Rename the feed if its name in the OPML file doesn't match the found name
		if sub.name != feedSpecifier.title, let newName = feedSpecifier.title {
			
			self.caller.renameSubscription(subscriptionID: String(sub.subscriptionID), newName: newName) { [weak self] result in
				switch result {
				case .success:
					DispatchQueue.main.async {
						feed.editedName = newName
					}
				case .failure(let error):
					guard let self = self else { return }
					os_log(.error, log: self.log, "Rename feed on OPML import failed: %@.", error.localizedDescription)
				}
			}
			
		}
		
		// Move the new feed if it is in a folder
		if let folder = parentFolder, let feedID = Int(feed.feedID) {
			
			self.caller.createTagging(feedID: feedID, name: folder.name ?? "") { [weak self] result in
				switch result {
				case .success(let taggingID):
					DispatchQueue.main.async {
						self?.saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
						folder.addFeed(feed)
					}
				case .failure(let error):
					guard let self = self else { return }
					os_log(.error, log: self.log, "Move feed to folder on OPML import failed: %@.", error.localizedDescription)
				}
			}
			
		} else {
			
			DispatchQueue.main.async {
				account.addFeed(feed)
			}
			
		}
		
	}
	
	func processRestoredFeed(for account: Account, feed: Feed, editedName: String?, folder: Folder?, completion: @escaping (Result<Void, Error>) -> Void) {
		
		if let folder = folder {
			
			addFeed(for: account, to: folder, with: feed) { [weak self] result in
				
				switch result {
				case .success:
					
					if editedName != nil {
						DispatchQueue.main.async {
							folder.addFeed(feed)
						}
						self?.processRestoredFeedName(for: account, feed: feed, editedName: editedName!, completion: completion)
					} else {
						DispatchQueue.main.async {
							folder.addFeed(feed)
							completion(.success(()))
						}
					}
					
				case .failure(let error):
					DispatchQueue.main.async {
						completion(.failure(error))
					}
				}
				
			}
			
		} else {
			
			DispatchQueue.main.async {
				account.addFeed(feed)
			}
			
			if editedName != nil {
				processRestoredFeedName(for: account, feed: feed, editedName: editedName!, completion: completion)
			}
			
		}
		
	}
	
	func processRestoredFeedName(for account: Account, feed: Feed, editedName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		renameFeed(for: account, with: feed, to: editedName) { result in
			switch result {
			case .success:
				DispatchQueue.main.async {
					feed.editedName = editedName
					completion(.success(()))
				}
			case .failure(let error):
				DispatchQueue.main.async {
					completion(.failure(error))
				}
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

	func decideBestFeedChoice(account: Account, url: String, choices: [FeedbinSubscriptionChoice], completion: @escaping (Result<Feed, Error>) -> Void) {
		
		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.UserEntered : FeedSpecifier.Source.HTMLLink
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			if let bestSubscription = choices.filter({ bestSpecifier.urlString == $0.url }).first {
				createFeed(for: account, url: bestSubscription.url, completion: completion)
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
	
	func createFeed( account: Account, subscription sub: FeedbinSubscription, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		DispatchQueue.main.async { [weak self] in
			
			let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.subscriptionID = String(sub.subscriptionID)
		
			// Download the initial articles
			self?.caller.retrieveEntries(feedID: feed.feedID) { [weak self] result in
				
				switch result {
				case .success(let (entries, page)):
					
					self?.processEntries(account: account, entries: entries) {
						self?.refreshArticles(account, page: page) {
							DispatchQueue.main.async {
								completion(.success(feed))
							}
						}
					}
					
				case .failure(let error):
					guard let self = self else { return }
					os_log(.error, log: self.log, "Initial articles download failed: %@.", error.localizedDescription)
					DispatchQueue.main.async {
						completion(.success(feed))
					}
				}
				
			}

		}
		
	}

	func refreshArticles(_ account: Account, completion: @escaping (() -> Void)) {

		os_log(.debug, log: log, "Refreshing articles...")
		
		caller.retrieveEntries() { [weak self] result in
			
			switch result {
			case .success(let (entries, page, lastPageNumber)):
				
				if let last = lastPageNumber {
					self?.refreshProgress.addToNumberOfTasksAndRemaining(last - 1)
				}
				
				self?.processEntries(account: account, entries: entries) {
					
					self?.refreshProgress.completeTask()
					self?.refreshArticles(account, page: page) {
						guard let self = self else { return }
						os_log(.debug, log: self.log, "Done refreshing articles.")
						completion()
					}
					
				}

			case .failure(let error):
				guard let self = self else { return }
				os_log(.error, log: self.log, "Refresh articles failed: %@.", error.localizedDescription)
				completion()
			}
			
		}
		
	}
	
	func refreshArticles(_ account: Account, page: String?, completion: @escaping (() -> Void)) {
		
		guard let page = page else {
			completion()
			return
		}
		
		caller.retrieveEntries(page: page) { [weak self] result in
			
			switch result {
			case .success(let (entries, nextPage)):
				
				self?.processEntries(account: account, entries: entries) {
					self?.refreshProgress.completeTask()
					self?.refreshArticles(account, page: nextPage, completion: completion)
				}
				
			case .failure(let error):
				guard let self = self else { return }
				os_log(.error, log: self.log, "Refresh articles for additional pages failed: %@.", error.localizedDescription)
			}
			
		}
		
	}
	
	func processEntries(account: Account, entries: [FeedbinEntry]?, completion: @escaping (() -> Void)) {
		
		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let parsedMap = Dictionary(grouping: parsedItems, by: { item in item.feedURL } )
		
		let group = DispatchGroup()
		
		for (feedID, mapItems) in parsedMap {
			
			group.enter()
			
			if let feed = account.idToFeedDictionary[feedID] {
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
			let authors = Set([ParsedAuthor(name: entry.authorName, url: nil, avatarURL: nil, emailAddress: nil)])
			return ParsedItem(syncServiceID: String(entry.articleID), uniqueID: String(entry.articleID), feedURL: String(entry.feedID), url: nil, externalURL: entry.url, title: entry.title, contentHTML: entry.contentHTML, contentText: nil, summary: entry.summary, imageURL: nil, bannerImageURL: nil, datePublished: entry.parseDatePublished(), dateModified: nil, authors: authors, tags: nil, attachments: nil)
		}
		
		return Set(parsedItems)
		
	}
	
	func syncArticleReadState(account: Account, articleIDs: [Int]?) {
		
		guard let articleIDs = articleIDs, !articleIDs.isEmpty else {
			return
		}

		let feedbinUnreadArticleIDs = Set(articleIDs.map { String($0) } )
		let currentUnreadArticleIDs = account.fetchUnreadArticleIDs()
		
		// Mark articles as unread
		let deltaUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
		let markUnreadArticles = account.fetchArticles(forArticleIDs: deltaUnreadArticleIDs)
		DispatchQueue.main.async {
			_ = account.markArticles(markUnreadArticles, statusKey: .read, flag: false)
		}
	
		// Mark articles as read
		let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(feedbinUnreadArticleIDs)
		let markReadArticles = account.fetchArticles(forArticleIDs: deltaReadArticleIDs)
		DispatchQueue.main.async {
			_ = account.markArticles(markReadArticles, statusKey: .read, flag: true)
		}
	
		// Save any unread statuses for articles we haven't yet received
		let markUnreadArticleIDs = Set(markUnreadArticles.map { $0.articleID })
		let missingUnreadArticleIDs = deltaUnreadArticleIDs.subtracting(markUnreadArticleIDs)
		if !missingUnreadArticleIDs.isEmpty {
			DispatchQueue.main.async {
				account.ensureStatuses(missingUnreadArticleIDs, .read, false)
			}
		}
		
	}
	
	func syncArticleStarredState(account: Account, articleIDs: [Int]?) {
		
		guard let articleIDs = articleIDs, !articleIDs.isEmpty else {
			return
		}

		let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) } )
		let currentStarredArticleIDs = account.fetchStarredArticleIDs()
		
		// Mark articles as starred
		let deltaStarredArticleIDs = feedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
		let markStarredArticles = account.fetchArticles(forArticleIDs: deltaStarredArticleIDs)
		DispatchQueue.main.async {
			_ = account.markArticles(markStarredArticles, statusKey: .starred, flag: true)
		}
		
		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(feedbinStarredArticleIDs)
		let markUnstarredArticles = account.fetchArticles(forArticleIDs: deltaUnstarredArticleIDs)
		DispatchQueue.main.async {
			_ = account.markArticles(markUnstarredArticles, statusKey: .starred, flag: false)
		}
		
		// Save any starred statuses for articles we haven't yet received
		let markStarredArticleIDs = Set(markStarredArticles.map { $0.articleID })
		let missingStarredArticleIDs = deltaStarredArticleIDs.subtracting(markStarredArticleIDs)
		if !missingStarredArticleIDs.isEmpty {
			DispatchQueue.main.async {
				account.ensureStatuses(missingStarredArticleIDs, .starred, true)
			}
		}
		
	}
	
}
