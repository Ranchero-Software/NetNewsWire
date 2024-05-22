//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Database
import Parser
import Web
import SyncDatabase
import os.log
import Secrets
import NewsBlur
import CommonErrors

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

	let caller: NewsBlurAPICaller
	let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "NewsBlur")
	let syncDatabase: SyncDatabase

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
			sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

			let session = URLSession(configuration: sessionConfiguration)
			caller = NewsBlurAPICaller(transport: session)
		}

		syncDatabase = SyncDatabase(databasePath: dataFolder.appending("/DB.sqlite3"))
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		
		refreshProgress.addToNumberOfTasksAndRemaining(4)

		try await refreshFeeds(for: account)
		refreshProgress.completeTask()

		try await sendArticleStatus(for: account)
		refreshProgress.completeTask()

		try await refreshArticleStatus(for: account)
		refreshProgress.completeTask()

		try await refreshMissingStories(for: account)
		refreshProgress.completeTask()
	}

	func syncArticleStatus(for account: Account) async throws {

		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	public func sendArticleStatus(for account: Account) async throws {

		os_log(.debug, log: log, "Sending story statuses…")

		let syncStatuses = (try await self.syncDatabase.selectForProcessing()) ?? Set<SyncStatus>()

		let createUnreadStatuses = syncStatuses.filter {
			$0.key == SyncStatus.Key.read && $0.flag == false
		}
		let deleteUnreadStatuses = syncStatuses.filter {
			$0.key == SyncStatus.Key.read && $0.flag == true
		}
		let createStarredStatuses = syncStatuses.filter {
			$0.key == SyncStatus.Key.starred && $0.flag == true
		}
		let deleteStarredStatuses = syncStatuses.filter {
			$0.key == SyncStatus.Key.starred && $0.flag == false
		}

		var errorOccurred = false

		do {
			try await sendStoryStatuses(createUnreadStatuses, throttle: true, apiCall: caller.markAsUnread)
		} catch {
			errorOccurred = true
		}

		do {
			try await sendStoryStatuses(deleteUnreadStatuses, throttle: false, apiCall: caller.markAsRead)
		} catch {
			errorOccurred = true
		}

		do {
			try await sendStoryStatuses(createStarredStatuses, throttle: true, apiCall: caller.star)
		} catch {
			errorOccurred = true
		}

		do {
			try await sendStoryStatuses(deleteStarredStatuses, throttle: true, apiCall: caller.unstar)
		} catch {
			errorOccurred = true
		}

		os_log(.debug, log: self.log, "Done sending article statuses.")
		if errorOccurred {
			throw NewsBlurError.unknown
		}
	}

	func refreshArticleStatus(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing story statuses…")

		var errorOccurred = false

		do {
			let storyHashes = try await caller.retrieveUnreadStoryHashes()
			await syncStoryReadState(account: account, hashes: storyHashes)
		} catch {
			errorOccurred = true
			os_log(.info, log: self.log, "Retrieving unread stories failed: %@.", error.localizedDescription)
		}

		do {
			let storyHashes = try await caller.retrieveStarredStoryHashes()
			await syncStoryStarredState(account: account, hashes: storyHashes)
		} catch {
			errorOccurred = true
			os_log(.info, log: self.log, "Retrieving starred stories failed: %@.", error.localizedDescription)
		}

		os_log(.debug, log: self.log, "Done refreshing article statuses.")
		if errorOccurred {
			throw NewsBlurError.unknown
		}
	}

	func refreshStories(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing stories…")
		os_log(.debug, log: log, "Refreshing unread stories…")

		let storyHashes = try await caller.retrieveUnreadStoryHashes()
		if let count = storyHashes?.count, count > 0 {
			refreshProgress.addToNumberOfTasksAndRemaining((count - 1) / 100 + 1)
		}

		let storyHashesArray: [NewsBlurStoryHash] = {
			if let storyHashes {
				return Array(storyHashes)
			}
			return [NewsBlurStoryHash]()
		}()
		try await refreshUnreadStories(for: account, hashes: storyHashesArray, updateFetchDate: nil)
	}

	func refreshMissingStories(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing missing stories…")

		let fetchedArticleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate() ?? Set<String>()

		var errorOccurred = false

		let storyHashes = Array(fetchedArticleIDs).map {
			NewsBlurStoryHash(hash: $0, timestamp: Date())
		}
		let chunkedStoryHashes = storyHashes.chunked(into: 100)

		for chunk in chunkedStoryHashes {
			do {
				let (stories, _) = try await caller.retrieveStories(hashes: chunk)
				try await processStories(account: account, stories: stories)
			} catch {
				errorOccurred = true
				os_log(.error, log: self.log, "Refresh missing stories failed: %@.", error.localizedDescription)
			}
		}

		os_log(.debug, log: self.log, "Done refreshing missing stories.")
		if errorOccurred {
			throw NewsBlurError.unknown
		}
	}

	@discardableResult
	func processStories(account: Account, stories: [NewsBlurStory]?, since: Date? = nil) async throws -> Bool {

		let parsedItems = mapStoriesToParsedItems(stories: stories).filter {
			guard let datePublished = $0.datePublished, let since = since else {
				return true
			}

			return datePublished >= since
		}
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues {
			Set($0)
		}

		try await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
		return !feedIDsAndItems.isEmpty
	}

	func importOPML(for account: Account, opmlFile: URL) async throws {
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {

		refreshProgress.addTask()

		try await caller.addFolder(named: name)
		refreshProgress.completeTask()

		if let folder = account.ensureFolder(with: name) {
			return folder
		} else {
			throw NewsBlurError.invalidParameter
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		guard let folderToRename = folder.name else {
			throw NewsBlurError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let nameBefore = folder.name

		do {
			try await caller.renameFolder(with: folderToRename, to: name)
			folder.name = name
		} catch {
			folder.name = nameBefore
			throw error
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {

		guard let folderToRemove = folder.name else {
			throw NewsBlurError.invalidParameter
		}

		var feedIDs: [String] = []
		for feed in folder.topLevelFeeds {
			if (feed.folderRelationship?.count ?? 0) > 1 {
				clearFolderRelationship(for: feed, withFolderName: folderToRemove)
			} else if let feedID = feed.externalID {
				feedIDs.append(feedID)
			}
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		try await caller.removeFolder(named: folderToRemove, feedIDs: feedIDs)
		account.removeFolder(folder: folder)
	}

	@discardableResult
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let folderName = (container as? Folder)?.name

		do {
			guard let newsBlurFeed = try await caller.addURL(url, folder: folderName) else {
				throw NewsBlurError.unknown
			}
			let feed = try await createFeed(account: account, newsBlurFeed: newsBlurFeed, name: name, container: container)
			return feed
		} catch {
			throw AccountError.wrappedError(error: error, account: account)
		}
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		guard let feedID = feed.externalID else {
			throw NewsBlurError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await caller.renameFeed(feedID: feedID, newName: name)
			feed.editedName = name
		} catch {
			throw AccountError.wrappedError(error: error, account: account)
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		if let account = container as? Account {
			account.addFeed(feed)
			return
		}

		guard let folder = container as? Folder else {
			return
		}
		let folderName = folder.name ?? ""
		saveFolderRelationship(for: feed, withFolderName: folderName, id: folderName)
		folder.addFeed(feed)
	}

	func removeFeed(for account: Account, with feed: Feed, from container: any Container) async throws {

		try await deleteFeed(for: account, with: feed, from: container)
	}

	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {
		
		guard let feedID = feed.externalID else {
			throw NewsBlurError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}
		

		try await caller.moveFeed( feedID: feedID, from: (from as? Folder)?.name, to: (to as? Folder)?.name)
		from.removeFeed(feed)
		to.addFeed(feed)
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		if let existingFeed = account.existingFeed(withURL: feed.url) {
			return try await account.addFeed(existingFeed, to: container)
		} else {
			try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {

		guard let folderName = folder.name else {
			throw NewsBlurError.invalidParameter
		}

		var feedsToRestore: [Feed] = []
		for feed in folder.topLevelFeeds {
			feedsToRestore.append(feed)
			folder.topLevelFeeds.remove(feed)
		}

		do {
			let folder = try await createFolder(for: account, name: folderName)
			for feed in feedsToRestore {
				do {
					try await restoreFeed(for: account, feed: feed, container: folder)
				} catch {
					os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
					throw error
				}
			}
		} catch {
			os_log(.error, log: self.log, "Restore folder error: %@.", error.localizedDescription)
			throw error
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		let articles = try await account.update(articles: articles, statusKey: statusKey, flag: flag)

		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		}
		try? await syncDatabase.insertStatuses(Set(syncStatuses))

		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .newsBlurSessionID)
	}

	func accountWillBeDeleted(_ account: Account) {
		Task { @MainActor in
			try await caller.logout()
		}
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		let caller = NewsBlurAPICaller(transport: transport)
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
			await syncDatabase.suspend()
		}
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {

		Task {
			caller.resume()
			await syncDatabase.resume()
		}
	}
}
