//
//  ReaderAPIAccountDelegate.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Parser
import Web
import SyncDatabase
import os.log
import Secrets
import Database
import Core
import ReaderAPI
import CommonErrors
import FeedFinder

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
	
	weak var accountMetadata: AccountMetadata?

	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	init(dataFolder: String, transport: Transport?, variant: ReaderAPIVariant, secretsProvider: SecretsProvider) {

		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.database = SyncDatabase(databasePath: databasePath)

		self.variant = variant

		if transport != nil {
			self.caller = ReaderAPICaller(transport: transport!, secretsProvider: secretsProvider)
		} else {
			let sessionConfiguration = URLSessionConfiguration.default
			sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
			sessionConfiguration.timeoutIntervalForRequest = 60.0
			sessionConfiguration.httpShouldSetCookies = false
			sessionConfiguration.httpCookieAcceptPolicy = .never
			sessionConfiguration.httpMaximumConnectionsPerHost = 1
			sessionConfiguration.httpCookieStorage = nil
			sessionConfiguration.urlCache = nil
			sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

			self.caller = ReaderAPICaller(transport: URLSession(configuration: sessionConfiguration), secretsProvider: secretsProvider)
		}
		
		caller.delegate = self
		caller.variant = variant
	}
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {

		refreshProgress.addTasks(6)

		do {
			try await refreshAccount(account)

			try await sendArticleStatus(for: account)
			refreshProgress.completeTask()
			
			let articleIDs = try await caller.retrieveItemIDs(type: .allForAccount)
			refreshProgress.completeTask()

			try? await account.markAsRead(Set(articleIDs))
			try? await refreshArticleStatus(for: account)
			refreshProgress.completeTask()

			await refreshMissingArticles(account)
			refreshProgress.clear()

		} catch {
			refreshProgress.clear()

			let wrappedError = AccountError.wrappedError(error: error, account: account)
			if wrappedError.isCredentialsError, let basicCredentials = try? account.retrieveCredentials(type: .readerBasic), let endpoint = account.endpointURL {

				self.caller.credentials = basicCredentials

				do {
					if let apiCredentials = try await caller.validateCredentials(endpoint: endpoint) {
						try? account.storeCredentials(apiCredentials)
						caller.credentials = apiCredentials
						try await refreshAll(for: account)
						return
					}
					throw wrappedError
				} catch {
					throw wrappedError
				}

			} else {
				throw wrappedError
			}
		}
	}

	func syncArticleStatus(for account: Account) async throws {

		guard variant != .inoreader else {
			return
		}
		
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}
	
	public func sendArticleStatus(for account: Account) async throws {

		os_log(.debug, log: log, "Sending article statuses...")

		let syncStatuses = (try await self.database.selectForProcessing()) ?? Set<SyncStatus>()

		let createUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false }
		let deleteUnreadStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true }
		let createStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true }
		let deleteStarredStatuses = syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false }

		await sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries)
		await sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries)
		await sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries)
		await sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries)

		os_log(.debug, log: self.log, "Done sending article statuses.")
	}

	func refreshArticleStatus(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing article statuses...")

		var errorOccurred = false

		let articleIDs = try await caller.retrieveItemIDs(type: .unread)

		do {
			try await syncArticleReadState(account: account, articleIDs: articleIDs)
		} catch {
			errorOccurred = true
			os_log(.info, log: self.log, "Retrieving unread entries failed: %@.", error.localizedDescription)
		}

		do {
			let articleIDs = try await caller.retrieveItemIDs(type: .starred)
			await syncArticleStarredState(account: account, articleIDs: articleIDs)
		} catch {
			errorOccurred = true
			os_log(.info, log: self.log, "Retrieving starred entries failed: %@.", error.localizedDescription)
		}

		os_log(.debug, log: self.log, "Done refreshing article statuses.")
		if errorOccurred {
			throw ReaderAPIError.unknown
		}
	}

	func importOPML(for account:Account, opmlFile: URL) async throws {
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {

		guard let folder = account.ensureFolder(with: name) else {
			throw ReaderAPIError.invalidParameter
		}
		return folder
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		refreshProgress.addTask()
		
		do {
			try await caller.renameTag(oldName: folder.name ?? "", newName: name)
			folder.externalID = "user/-/label/\(name)"
			folder.name = name

			refreshProgress.completeTask()
		} catch {
			refreshProgress.completeTask()

			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {

		for feed in folder.topLevelFeeds {

			if feed.folderRelationship?.count ?? 0 > 1 {

				if let subscriptionID = feed.externalID {

					refreshProgress.addTask()

					do {
						try await caller.deleteTagging(subscriptionID: subscriptionID, tagName: folder.nameForDisplay)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
						refreshProgress.completeTask()
					} catch {
						refreshProgress.completeTask()
						os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
					}
				}

			} else {

				if let subscriptionID = feed.externalID {
					refreshProgress.addTask()

					do {
						try await caller.deleteSubscription(subscriptionID: subscriptionID)
						account.clearFeedMetadata(feed)

						refreshProgress.completeTask()
					} catch {

						refreshProgress.completeTask()
						os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
					}
				}
			}
		}

		if self.variant == .theOldReader {
			account.removeFolder(folder: folder)
		} else {
			if let folderExternalID = folder.externalID {
				try await caller.deleteTag(folderExternalID: folderExternalID)
			}
			account.removeFolder(folder: folder)
		}
	}

	@discardableResult
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		guard let url = URL(string: url) else {
			throw ReaderAPIError.invalidParameter
		}

		refreshProgress.addTasks(2)

		do {

			let feedSpecifiers = try await FeedFinder.find(url: url)
			refreshProgress.completeTask()

			let filteredFeedSpecifiers = feedSpecifiers.filter { !$0.urlString.contains("json") }
			guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: filteredFeedSpecifiers) else {
				refreshProgress.clear()
				throw AccountError.createErrorNotFound
			}

			let subResult = try await caller.createSubscription(url: bestFeedSpecifier.urlString, name: name)
			refreshProgress.completeTask()

			switch subResult {
			case .created(let subscription):
				return try await createFeed(account: account, subscription: subscription, name: name, container: container)
			case .notFound:
				throw AccountError.createErrorNotFound
			}

		} catch {
			refreshProgress.clear()
			throw AccountError.createErrorNotFound
		}
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			assert(feed.externalID != nil)
			throw ReaderAPIError.invalidParameter
		}
		
		refreshProgress.addTask()
		
		do {
			try await caller.renameSubscription(subscriptionID: subscriptionID, newName: name)
			feed.editedName = name
			refreshProgress.completeTask()
		} catch {
			refreshProgress.completeTask()
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}
	
	func removeFeed(for account: Account, with feed: Feed, from container: any Container) async throws {

		guard let subscriptionID = feed.externalID else {
			assert(feed.externalID != nil)
			throw ReaderAPIError.invalidParameter
		}
		
		refreshProgress.addTask()

		do {
			try await caller.deleteSubscription(subscriptionID: subscriptionID)

			account.clearFeedMetadata(feed)
			account.removeFeed(feed)
			if let folders = account.folders {
				for folder in folders {
					folder.removeFeed(feed)
				}
			}

			refreshProgress.completeTask()
		} catch {
			refreshProgress.completeTask()
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}
	
	func moveFeed(for account: Account, with feed: Feed, from sourceContainer: Container, to destinationContainer: Container) async throws {

		if sourceContainer is Account {
			try await addFeed(for: account, with: feed, to: destinationContainer)
		} else {

			guard
				let subscriptionID = feed.externalID,
				let sourceTag = (sourceContainer as? Folder)?.name,
				let destinationTag = (destinationContainer as? Folder)?.name
			else {
				throw ReaderAPIError.invalidParameter
			}

			refreshProgress.addTask()

			do {
				try await caller.moveSubscription(subscriptionID: subscriptionID, sourceTag: sourceTag, destinationTag: destinationTag)
				refreshProgress.completeTask()
				sourceContainer.removeFeed(feed)
				destinationContainer.addFeed(feed)
				refreshProgress.completeTask()
			} catch {
				refreshProgress.completeTask()
				throw error
			}
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		if let folder = container as? Folder, let feedExternalID = feed.externalID {

			refreshProgress.addTask()

			do {

				try await caller.createTagging(subscriptionID: feedExternalID, tagName: folder.name ?? "")

				self.saveFolderRelationship(for: feed, folderExternalID: folder.externalID, feedExternalID: feedExternalID)
				account.removeFeed(feed)
				folder.addFeed(feed)

				refreshProgress.completeTask()

			} catch {

				refreshProgress.completeTask()
				let wrappedError = AccountError.wrappedError(error: error, account: account)
				throw wrappedError
			}
		} else {

			if let account = container as? Account {
				account.addFeedIfNotInAnyFolder(feed)
			}
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, to: container)
		}
		else {
			try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {

		for feed in folder.topLevelFeeds {
			
			folder.topLevelFeeds.remove(feed)
			
			do {
				try await restoreFeed(for: account, feed: feed, container: folder)
			} catch {
				os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
			}
		}

		account.addFolder(folder)
	}
	
	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		let articles = try await account.update(articles: articles, statusKey: statusKey, flag: flag)

		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		}

		try await self.database.insertStatuses(Set(syncStatuses))

		if let count = try await self.database.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .readerAPIKey)
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {
		
		guard let endpoint else {
			throw TransportError.noURL
		}
		
		let caller = ReaderAPICaller(transport: transport, secretsProvider: secretsProvider)
		caller.credentials = credentials
		
		return try await caller.validateCredentials(endpoint: endpoint)
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.cancelAll()
	}
	
	/// Suspend the SQLite databases
	func suspendDatabase() {

		Task {
			await database.suspend()
		}
	}
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {

		Task {
			await database.resume()
		}
	}
}

// MARK: Private

private extension ReaderAPIAccountDelegate {
	
	func refreshAccount(_ account: Account) async throws {

		let tags = try await caller.retrieveTags()
		refreshProgress.completeTask()

		let subscriptions = try await caller.retrieveSubscriptions()
		refreshProgress.completeTask()

		BatchUpdate.shared.perform {
			self.syncFolders(account, tags)
			self.syncFeeds(account, subscriptions)
			self.syncFeedFolderRelationship(account, subscriptions)
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
			for folder in folders {
				if !readerFolderExternalIDs.contains(folder.externalID ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					}
					account.removeFolder(folder: folder)
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
		for tag in folderTags {
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
		
		let subFeedIDs = subscriptions.map { $0.feedID }
		
		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIDs.contains(feed.feedID) {
						folder.removeFeed(feed)
					}
				}
			}
		}
		
		for feed in account.topLevelFeeds {
			if !subFeedIDs.contains(feed.feedID) {
				account.clearFeedMetadata(feed)
				account.removeFeed(feed)
			}
		}
		
		// Add any feeds we don't have and update any we do
		for subscription in subscriptions {

			if let feed = account.existingFeed(withFeedID: subscription.feedID) {
				feed.name = subscription.name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: subscription.feedID, homePageURL: subscription.homePageURL)
				feed.externalID = subscription.feedID
				account.addFeed(feed)
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
			
			for category in subscription.categories {
				if var taggedFeed = taggedFeeds[category.categoryID] {
					taggedFeed.append(subscription)
					taggedFeeds[category.categoryID] = taggedFeed
				} else {
					taggedFeeds[category.categoryID] = [subscription]
				}
			}
			
			return taggedFeeds
		}
		
		// Sync the folders
		for (folderExternalID, groupedTaggings) in taggingsDict {
			guard let folder = folderDict[folderExternalID] else { return }
			let taggingFeedIDs = groupedTaggings.map { $0.feedID }
			
			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					folder.removeFeed(feed)
					clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					account.addFeed(feed)
				}
			}
			
			// Add any feeds not in the folder
			let folderFeedIDs = folder.topLevelFeeds.map { $0.feedID }
			
			for subscription in groupedTaggings {
				let taggingFeedID = subscription.feedID
				if !folderFeedIDs.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, folderExternalID: folderExternalID, feedExternalID: subscription.feedID)
					folder.addFeed(feed)
				}
			}
			
		}
	
		let taggedFeedIDs = Set(subscriptions.filter({ !$0.categories.isEmpty }).map { String($0.feedID) })
		
		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
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

	func sendArticleStatuses(_ statuses: Set<SyncStatus>, apiCall: ([String]) async throws -> Void) async {

		guard !statuses.isEmpty else {
			return
		}

		let articleIDs = statuses.compactMap { $0.articleID }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {

			do {
				let _ = try await apiCall(articleIDGroup)
				try? await database.deleteSelectedForProcessing(Set(articleIDGroup))
			} catch {
				os_log(.error, log: self.log, "Article status sync call failed: %@.", error.localizedDescription)
				try? await database.resetSelectedForProcessing(Set(articleIDGroup))
			}
		}
	}

	func clearFolderRelationship(for feed: Feed, folderExternalID: String?) {
		guard var folderRelationship = feed.folderRelationship, let folderExternalID = folderExternalID else { return }
		folderRelationship[folderExternalID] = nil
		feed.folderRelationship = folderRelationship
	}
	
	func saveFolderRelationship(for feed: Feed, folderExternalID: String?, feedExternalID: String) {
		guard let folderExternalID = folderExternalID else { return }
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderExternalID] = feedExternalID
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderExternalID: feedExternalID]
		}
	}
	
	func createFeed( account: Account, subscription sub: ReaderAPISubscription, name: String?, container: Container) async throws -> Feed {

		let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
		feed.externalID = String(sub.feedID)

		try await account.addFeed(feed, to: container)
		if let name {
			try await renameFeed(for: account, with: feed, to: name)
		}
		try await initialFeedDownload(account: account, feed: feed)

		return feed
	}


	@discardableResult
	func initialFeedDownload( account: Account, feed: Feed) async throws -> Feed {

		refreshProgress.addTasks(5)

		// Download the initial articles
		let articleIDs = try await caller.retrieveItemIDs(type: .allForFeed, feedID: feed.feedID)

		refreshProgress.completeTask()

		try? await account.markAsRead(Set(articleIDs))
		refreshProgress.completeTask()

		try? await refreshArticleStatus(for: account)
		refreshProgress.completeTask()

		await refreshMissingArticles(account)
		refreshProgress.clear()

		return feed
	}
	
	func refreshMissingArticles(_ account: Account) async {

		do {
			let fetchedArticleIDs = (try? await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate()) ?? Set<String>()

			if fetchedArticleIDs.isEmpty {
				return
			}

			os_log(.debug, log: self.log, "Refreshing missing articles...")

			let articleIDs = Array(fetchedArticleIDs)
			let chunkedArticleIDs = articleIDs.chunked(into: 150)

			refreshProgress.addTasks(chunkedArticleIDs.count - 1)

			for chunk in chunkedArticleIDs {

				do {
					let entries = try await caller.retrieveEntries(articleIDs: chunk)
					refreshProgress.completeTask()
					await processEntries(account: account, entries: entries)
				} catch {
					os_log(.error, log: self.log, "Refresh missing articles failed: %@.", error.localizedDescription)
				}
			}

			refreshProgress.completeTask()
			os_log(.debug, log: self.log, "Done refreshing missing articles.")
		}
	}

	func processEntries(account: Account, entries: [ReaderAPIEntry]?) async {

		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }

		try? await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}
	
	func mapEntriesToParsedItems(account: Account, entries: [ReaderAPIEntry]?) -> Set<ParsedItem> {
		
		guard let entries else {
			return Set<ParsedItem>()
		}
		
		let parsedItems: [ParsedItem] = entries.compactMap { entry in

			guard let streamID = entry.origin.streamID else {
				return nil
			}

			let authors: Set<ParsedAuthor>? = {
				guard let name = entry.author else {
					return nil
				}
				return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
			}()

			return ParsedItem(syncServiceID: entry.uniqueID(variant: variant),
							  uniqueID: entry.uniqueID(variant: variant),
							  feedURL: streamID,
							  url: nil,
							  externalURL: entry.alternates?.first?.url,
							  title: entry.title,
							  language: nil,
							  contentHTML: entry.summary.content,
							  contentText: nil,
							  summary: entry.summary.content,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: entry.parseDatePublished(),
							  dateModified: nil,
							  authors: authors,
							  tags: nil,
							  attachments: nil)
		}
		
		return Set(parsedItems)
	}
	
	func syncArticleReadState(account: Account, articleIDs: [String]?) async throws {

		guard let articleIDs else {
			return
		}
		
		Task { @MainActor in
			do {
				
				let pendingArticleIDs = (try await self.database.selectPendingReadStatusArticleIDs()) ?? Set<String>()
				
				let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
				
				guard let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDs() else {
					return
				}

				// Mark articles as unread
				let deltaUnreadArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
				try? await account.markAsUnread(deltaUnreadArticleIDs)

				// Mark articles as read
				let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
				try? await account.markAsRead(deltaReadArticleIDs)

			} catch {
				os_log(.error, log: self.log, "Sync Article Read Status failed: %@.", error.localizedDescription)
			}
		}
	}

	func syncArticleStarredState(account: Account, articleIDs: [String]?) async {

		guard let articleIDs else {
			return
		}

		do {

			let pendingArticleIDs = (try await self.database.selectPendingStarredStatusArticleIDs()) ?? Set<String>()

			let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)

			guard let currentStarredArticleIDs = try await account.fetchStarredArticleIDs() else {
				return
			}

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentStarredArticleIDs)
			try? await account.markAsStarred(deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
			try? await account.markAsUnstarred(deltaUnstarredArticleIDs)

		} catch {
			os_log(.error, log: self.log, "Sync Article Starred Status failed: %@.", error.localizedDescription)
		}
	}
}

extension ReaderAPIAccountDelegate: ReaderAPICallerDelegate {

	var endpointURL: URL? {
		accountMetadata?.endpointURL
	}

	var lastArticleFetchStartTime: Date? {
		get {
			accountMetadata?.lastArticleFetchStartTime
		}
		set {
			accountMetadata?.lastArticleFetchStartTime = newValue
		}
	}

	var lastArticleFetchEndTime: Date? {
		get {
			accountMetadata?.lastArticleFetchEndTime
		}
		set {
			accountMetadata?.lastArticleFetchEndTime = newValue
		}
	}
}
