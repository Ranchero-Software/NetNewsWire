//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Database
import Parser
import Web
import SyncDatabase
import os.log
import Secrets
import Core
import Feedbin
import CommonErrors
import FeedFinder

public enum FeedbinAccountDelegateError: String, Error {
	case invalidParameter = "There was an invalid parameter passed."
	case unknown = "An unknown error occurred."
}

@MainActor final class FeedbinAccountDelegate: AccountDelegate {

	private let database: SyncDatabase
	
	private let caller: FeedbinAPICaller
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Feedbin")

	let behaviors: AccountBehaviors = [.disallowFeedCopyInRootFolder]
	let server: String? = "api.feedbin.com"
	var isOPMLImportInProgress = false
	
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	weak var accountMetadata: AccountMetadata?
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)

	init(dataFolder: String, transport: Transport?) {
		
		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		database = SyncDatabase(databasePath: databasePath)

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
			sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

			caller = FeedbinAPICaller(transport: URLSession(configuration: sessionConfiguration))
		}

		caller.delegate = self
	}
		
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {

		refreshProgress.addTasks(7)
		defer {
			refreshProgress.clear()
		}

		do {
			try await refreshAccount(account) // 3 tasks
			try await refreshArticlesAndStatuses(account) // 4 tasks
		} catch {
			throw AccountError.wrappedError(error: error, account: account)
		}
	}

	func syncArticleStatus(for account: Account) async throws {

		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	public func sendArticleStatus(for account: Account) async throws {

		os_log(.debug, log: log, "Sending article statuses...")

		let syncStatuses = (try await self.database.selectForProcessing()) ?? Set<SyncStatus>()

		let createUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false })
		let deleteUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true })
		let createStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true })
		let deleteStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false })

		try await sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries)
		try await sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries)
		try await sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries)
		try await sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries)

		os_log(.debug, log: self.log, "Done sending article statuses.")
	}

	func refreshArticleStatus(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing article statuses...")

		var readStateSyncError: Error? = nil
		var starredStateSyncError: Error? = nil

		do {
			let articleIDs = try await caller.retrieveUnreadEntries()
			await syncArticleReadState(account: account, articleIDs: articleIDs)
		} catch {
			readStateSyncError = error
			os_log(.info, log: self.log, "Retrieving unread entries failed: %@.", error.localizedDescription)
		}

		do {
			let articleIDs = try await caller.retrieveStarredEntries()
			await syncArticleStarredState(account: account, articleIDs: articleIDs)
		} catch {
			starredStateSyncError = error
			os_log(.info, log: self.log, "Retrieving starred entries failed: %@.", error.localizedDescription)
		}

		os_log(.debug, log: self.log, "Done refreshing article statuses.")
		if let error = readStateSyncError ?? starredStateSyncError {
			throw error
		}
	}
	
	func importOPML(for account: Account, opmlFile: URL) async throws {

		let opmlData = try Data(contentsOf: opmlFile)
		if opmlData.isEmpty {
			return
		}

		os_log(.debug, log: log, "Begin importing OPML...")
		isOPMLImportInProgress = true
		refreshProgress.addTask()

		do {
			let importResult = try await caller.importOPML(opmlData: opmlData)

			if importResult.complete {
				os_log(.debug, log: self.log, "Import OPML done.")

				refreshProgress.completeTask()
				isOPMLImportInProgress = false
			} else {
				try await checkImportResult(opmlImportResultID: importResult.importResultID)

				refreshProgress.completeTask()
				isOPMLImportInProgress = false
			}

		} catch {
			os_log(.debug, log: self.log, "Import OPML failed.")

			refreshProgress.completeTask()
			isOPMLImportInProgress = false

			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}
	
	func createFolder(for account: Account, name: String) async throws -> Folder {

		guard let folder = account.ensureFolder(with: name) else {
			throw FeedbinAccountDelegateError.invalidParameter
		}
		return folder
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		guard folder.hasAtLeastOneFeed() else {
			folder.name = name
			return
		}

		refreshProgress.addTask()
		defer {
			self.refreshProgress.completeTask()
		}

		do {
			try await caller.renameTag(oldName: folder.name ?? "", newName: name)
			renameFolderRelationship(for: account, fromName: folder.name ?? "", toName: name)
			folder.name = name
		} catch {
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {

		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.removeFolder(folder: folder)
			return
		}
		
		let feeds = folder.topLevelFeeds
		let numberOfFeeds = feeds.count
		refreshProgress.addTasks(numberOfFeeds)

		for feed in feeds {

			if feed.folderRelationship?.count ?? 0 > 1 {

				if let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
					do {
						try await caller.deleteTagging(taggingID: feedTaggingID)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					} catch {
						os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
						throw error
					}
				}
			} else {

				if let subscriptionID = feed.externalID {

					do {
						try await caller.deleteSubscription(subscriptionID: subscriptionID)
						account.clearFeedMetadata(feed)
					} catch {
						os_log(.error, log: self.log, "Remove feed error: %@.", error.localizedDescription)
						throw error
					}
				}
			}

			refreshProgress.completeTask()
		}

		account.removeFolder(folder: folder)
	}
	
	@discardableResult
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			let subResult = try await caller.createSubscription(url: url)

			switch subResult {

			case .created(let subscription):
				return try await createFeed(account: account, subscription: subscription, name: name, container: container)

			case .multipleChoice(let choices):
				return try await decideBestFeedChoice(account: account, url: url, name: name, container: container, choices: choices)

			case .alreadySubscribed:
				throw AccountError.createErrorAlreadySubscribed

			case .notFound:
				throw AccountError.createErrorNotFound
			}

		} catch {
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			throw FeedbinAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await caller.renameSubscription(subscriptionID: subscriptionID, newName: name)
			feed.editedName = name
		} catch {
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	func removeFeed(for account: Account, with feed: Feed, from container: any Container) async throws {

		if feed.folderRelationship?.count ?? 0 > 1 {
			try await deleteTagging(for: account, with: feed, from: container)
		} else {
			try await deleteSubscription(for: account, with: feed, from: container)
		}
	}

	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {

		if from is Account {
			try await addFeed(for: account, with: feed, to: to)
		} else {
			try await deleteTagging(for: account, with: feed, from: from)
			try await addFeed(for: account, with: feed, to: to)
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		if let folder = container as? Folder, let feedID = Int(feed.feedID) {

			refreshProgress.addTask()
			defer { refreshProgress.completeTask() }

			do {
				let taggingID = try await caller.createTagging(feedID: feedID, name: folder.name ?? "")

				saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
				account.removeFeed(feed)
				folder.addFeed(feed)
			} catch {
				let wrappedError = AccountError.wrappedError(error: error, account: account)
				throw wrappedError
			}

		} else if let account = container as? Account {
			account.addFeedIfNotInAnyFolder(feed)
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, to: container)
		} else {
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
				throw error
			}
		}

		account.addFolder(folder)
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		let articles = try await account.update(articles: articles, statusKey: statusKey, flag: flag)

		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		}

		try? await database.insertStatuses(Set(syncStatuses))

		if let count = try? await database.selectPendingCount(), count > 100 {
			try? await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .basic)
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		let caller = FeedbinAPICaller(transport: transport)
		caller.credentials = credentials
		return try await caller.validateCredentials()
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}
	
	/// Suspend the SQLLite databases
	func suspendDatabase() {

		Task {
			await database.suspend()
		}
	}
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {

		caller.resume()
		Task {
			await database.resume()
		}
	}
}

// MARK: Private

private extension FeedbinAccountDelegate {
	
	func checkImportResult(opmlImportResultID: Int) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.checkImportResult(opmlImportResultID: opmlImportResultID) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func delay(seconds: Double) async {

		await withCheckedContinuation { continuation in
			self.performBlockAfter(seconds: seconds) {
				continuation.resume()
			}
		}
	}

	nonisolated private func performBlockAfter(seconds: Double, block: @escaping @Sendable @MainActor () -> ()) {

		let delayTime = DispatchTime.now() + seconds
		DispatchQueue.main.asyncAfter(deadline: delayTime) {
			Task { @MainActor in
				block()
			}
		}
	}

	func checkImportResult(opmlImportResultID: Int, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		Task { @MainActor in

			var retry = 0
			let maxRetries = 6 // a guess at a good number

			@MainActor func checkResult() async {

				if retry >= maxRetries {
					return
				}
				retry = retry + 1

				await delay(seconds: 15)
				os_log(.debug, log: self.log, "Checking status of OPML import...")

				do {
					let importResult = try await self.caller.retrieveOPMLImportResult(importID: opmlImportResultID)

					if let importResult, importResult.complete {
						os_log(.debug, log: self.log, "Checking status of OPML import successfully completed.")
						completion(.success(()))
					} else {
						await checkResult()
					}

				} catch {
					os_log(.debug, log: self.log, "Import OPML check failed.")
					completion(.failure(error))
				}
			}

			await checkResult()
		}
	}

	func refreshAccount(_ account: Account) async throws {

		let tags = try await caller.retrieveTags()
		refreshProgress.completeTask()

		let subscriptions = try await caller.retrieveSubscriptions()
		refreshProgress.completeTask()
		forceExpireFolderFeedRelationship(account, tags)

		let taggings = try await caller.retrieveTaggings()
		BatchUpdate.shared.perform {
			self.syncFolders(account, tags)
			self.syncFeeds(account, subscriptions)
			self.syncFeedFolderRelationship(account, taggings)
		}
		refreshProgress.completeTask()
	}

	func refreshArticlesAndStatuses(_ account: Account) async throws {
		
		try await sendArticleStatus(for: account)
		refreshProgress.completeTask()

		try await refreshArticleStatus(for: account)
		refreshProgress.completeTask()

		try await refreshArticles(account)
		refreshProgress.completeTask()

		try await refreshMissingArticles(account)
		refreshProgress.completeTask()
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
		for tag in tags {
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
			for folder in folders {
				if !tagNames.contains(folder.name ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolder(folder: folder)
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
		for tagName in tagNames {
			if !folderNames.contains(tagName) {
				_ = account.ensureFolder(with: tagName)
			}
		}
	}
	
	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {
		
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing feeds with %ld subscriptions.", subscriptions.count)
		
		let subFeedIDs = subscriptions.map { String($0.feedID) }
		
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
				account.removeFeed(feed)
			}
		}
		
		// Add any feeds we don't have and update any we do
		var subscriptionsToAdd = Set<FeedbinSubscription>()
		for subscription in subscriptions {

			let subFeedID = String(subscription.feedID)

			if let feed = account.existingFeed(withFeedID: subFeedID) {
				feed.name = subscription.name
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
				feed.externalID = String(subscription.subscriptionID)
				feed.faviconURL = subscription.jsonFeed?.favicon
				feed.iconURL = subscription.jsonFeed?.icon
			}
			else {
				subscriptionsToAdd.insert(subscription)
			}
		}

		// Actually add subscriptions all in one go, so we don’t trigger various rebuilding things that Account does.
		for subscription in subscriptionsToAdd {
			let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
			feed.externalID = String(subscription.subscriptionID)
			account.addFeed(feed)
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ taggings: [FeedbinTagging]?) {
		
		guard let taggings = taggings else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing taggings with %ld taggings.", taggings.count)
		
		// Set up some structures to make syncing easier
		let folderDict = nameToFolderDictionary(with: account.folders)
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
			let folderFeedIDs = folder.topLevelFeeds.map { $0.feedID }
			
			for tagging in groupedTaggings {
				let taggingFeedID = String(tagging.feedID)
				if !folderFeedIDs.contains(taggingFeedID) {
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

	func nameToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()
		for folder in folders {
			let name = folder.name ?? ""
			if d[name] == nil {
				d[name] = folder
			}
		}
		return d
	}

	func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([Int]) async throws -> Void) async throws {

		guard !statuses.isEmpty else {
			return
		}
		
		var localError: Error?

		let articleIDs = statuses.compactMap { Int($0.articleID) }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {
			
			let articleIDsGroupAsString = Set(articleIDGroup.map { String($0) })
			do {
				try await apiCall(articleIDGroup)
				try? await database.deleteSelectedForProcessing(articleIDsGroupAsString)
			} catch {
				try? await database.resetSelectedForProcessing(articleIDsGroupAsString)
				localError = error
				os_log(.error, log: self.log, "Article status sync call failed: %@.", error.localizedDescription)
			}
		}
		
		if let localError {
			throw localError
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

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [FeedbinSubscriptionChoice]) async throws -> Feed {

		var orderFound = 0

		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.UserEntered : FeedSpecifier.Source.HTMLLink
			orderFound = orderFound + 1
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source, orderFound: orderFound)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			return try await createFeed(for: account, url: bestSpecifier.urlString, name: name, container: container, validateFeed: true)
		} else {
			throw FeedbinAccountDelegateError.invalidParameter
		}
	}

	func createFeed( account: Account, subscription sub: FeedbinSubscription, name: String?, container: Container) async throws -> Feed {

		let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
		feed.externalID = String(sub.subscriptionID)
		feed.iconURL = sub.jsonFeed?.icon
		feed.faviconURL = sub.jsonFeed?.favicon

		try await account.addFeed(feed, to: container)
		if let name {
			try await self.renameFeed(for: account, with: feed, to: name)
		}
		return try await initialFeedDownload(account: account, feed: feed)
	}

	func initialFeedDownload( account: Account, feed: Feed) async throws -> Feed {

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		let (entries, page) = try await caller.retrieveEntries(feedID: feed.feedID)
		try await processEntries(account: account, entries: entries)
		try await refreshArticleStatus(for: account)
		try await refreshArticles(account, page: page, updateFetchDate: nil)
		try await refreshMissingArticles(account)

		return feed
	}

	func refreshArticles(_ account: Account) async throws {

		os_log(.debug, log: log, "Refreshing articles...")

		let (entries, page, updateFetchDate, _) = try await caller.retrieveEntries()
		try await self.processEntries(account: account, entries: entries)
		try await refreshArticles(account, page: page, updateFetchDate: updateFetchDate)

		os_log(.debug, log: self.log, "Done refreshing articles.")
	}

	func refreshMissingArticles(_ account: Account) async throws {

		os_log(.debug, log: log, "Refreshing missing articles...")

		let fetchedArticleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate() ?? Set<String>()

		let articleIDs = Array(fetchedArticleIDs)
		let chunkedArticleIDs = articleIDs.chunked(into: 100)

		for chunk in chunkedArticleIDs {

			do {
				let entries = try await self.caller.retrieveEntries(articleIDs: chunk)
				try await self.processEntries(account: account, entries: entries)
			} catch {
				os_log(.error, log: self.log, "Refresh missing articles failed: %@.", error.localizedDescription)
			}
		}

		os_log(.debug, log: self.log, "Done refreshing missing articles.")
	}

	func refreshArticles(_ account: Account, page: String?, updateFetchDate: Date?) async throws {

		guard let page else {
			if let lastArticleFetch = updateFetchDate {
				accountMetadata?.lastArticleFetchStartTime = lastArticleFetch
				accountMetadata?.lastArticleFetchEndTime = Date()
			}
			return
		}

		let (entries, nextPage) = try await caller.retrieveEntries(page: page)
		try await processEntries(account: account, entries: entries)
		try await refreshArticles(account, page: nextPage, updateFetchDate: updateFetchDate)
	}

	func processEntries(account: Account, entries: [FeedbinEntry]?) async throws {

		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }

		try await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(entries: [FeedbinEntry]?) -> Set<ParsedItem> {
		guard let entries = entries else {
			return Set<ParsedItem>()
		}
		
		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			return ParsedItem(syncServiceID: String(entry.articleID), uniqueID: String(entry.articleID), feedURL: String(entry.feedID), url: entry.url, externalURL: entry.jsonFeed?.jsonFeedExternalURL, title: entry.title, language: nil, contentHTML: entry.contentHTML, contentText: nil, summary: entry.summary, imageURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: nil)
		}
		
		return Set(parsedItems)
		
	}
	
	func syncArticleReadState(account: Account, articleIDs: [Int]?) async {

		guard let articleIDs, !articleIDs.isEmpty else {
			return
		}

		do {

			let pendingArticleIDs = (try await self.database.selectPendingReadStatusArticleIDs()) ?? Set<String>()

			let feedbinUnreadArticleIDs = Set(articleIDs.map { String($0) } )
			let updatableFeedbinUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(pendingArticleIDs)

			guard let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDs() else {
				return
			}

			// Mark articles as unread
			let deltaUnreadArticleIDs = updatableFeedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
			try? await account.markAsUnread(deltaUnreadArticleIDs)

			// Mark articles as read
			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableFeedbinUnreadArticleIDs)
			try? await account.markAsRead(deltaReadArticleIDs)

		} catch {
			os_log(.error, log: self.log, "Sync Article Read Status failed: %@.", error.localizedDescription)
		}
	}

	func syncArticleStarredState(account: Account, articleIDs: [Int]?) async {

		guard let articleIDs, !articleIDs.isEmpty else {
			return
		}

		do {
			let pendingArticleIDs = (try await self.database.selectPendingStarredStatusArticleIDs()) ?? Set<String>()

			let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) } )
			let updatableFeedbinStarredArticleIDs = feedbinStarredArticleIDs.subtracting(pendingArticleIDs)

			guard let currentStarredArticleIDs = try await account.fetchStarredArticleIDs() else {
				return
			}

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableFeedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
			try? await account.markAsStarred(deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableFeedbinStarredArticleIDs)
			try? await account.markAsUnstarred(deltaUnstarredArticleIDs)

		} catch {
			os_log(.error, log: self.log, "Sync Article Starred Status failed: %@.", error.localizedDescription)
		}
	}

	func deleteTagging(for account: Account, with feed: Feed, from container: Container?) async throws {

		if let folder = container as? Folder, let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {

			refreshProgress.addTask()
			defer { refreshProgress.completeTask() }

			do {
				try await caller.deleteTagging(taggingID: feedTaggingID)

				clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
				folder.removeFeed(feed)
				account.addFeedIfNotInAnyFolder(feed)
			} catch {
				let wrappedError = AccountError.wrappedError(error: error, account: account)
				throw wrappedError
			}
		} else {
			if let account = container as? Account {
				account.removeFeed(feed)
			}
		}
	}

	func deleteSubscription(for account: Account, with feed: Feed, from container: Container?) async throws {

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			throw FeedbinAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await caller.deleteSubscription(subscriptionID: subscriptionID)

			account.clearFeedMetadata(feed)
			account.removeFeed(feed)
			if let folders = account.folders {
				for folder in folders {
					folder.removeFeed(feed)
				}
			}

		} catch {
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}
}

extension FeedbinAccountDelegate: FeedbinAPICallerDelegate {

	@MainActor var conditionalGetInfo: [String: HTTPConditionalGetInfo] {
		get {
			accountMetadata?.conditionalGetInfo ?? [String: HTTPConditionalGetInfo]()
		}
		set {
			accountMetadata?.conditionalGetInfo = newValue
		}
	}

	@MainActor var lastArticleFetchStartTime: Date? {
		accountMetadata?.lastArticleFetchStartTime
	}
}
