//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSDatabase
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

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
	let syncDatabase: SyncDatabase

	static let logger = NewsBlur.logger

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

			if let userAgentHeaders = UserAgent.headers() {
				sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
			}

			let session = URLSession(configuration: sessionConfiguration)
			caller = NewsBlurAPICaller(transport: session)
		}

		syncDatabase = SyncDatabase(databasePath: dataFolder.appending("/DB.sqlite3"))
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		refreshProgress.reset()
		self.refreshProgress.addToNumberOfTasksAndRemaining(4)

		do {
			try await refreshFeeds(for: account)
			refreshProgress.completeTask()

			try await sendArticleStatus(for: account)
			refreshProgress.completeTask()

			try await refreshArticleStatus(for: account)
			refreshProgress.completeTask()

			try await refreshMissingStories(for: account)
			refreshProgress.completeTask()
		} catch {
			refreshProgress.reset()
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
		Self.logger.info("NewsBlur: Sending story statuses")
		defer {
			Self.logger.info("NewsBlur: Finished sending article statuses")
		}

		guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
			return
		}

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

		var savedError: Error?

		do {
			try await sendStoryStatuses(createUnreadStatuses, throttle: true, apiCall: caller.markAsUnread)
		} catch {
			savedError = error
		}

		do {
			try await sendStoryStatuses(deleteUnreadStatuses, throttle: false, apiCall: caller.markAsRead)
		} catch {
			savedError = error
		}

		do {
			try await sendStoryStatuses(createStarredStatuses, throttle: true, apiCall: caller.star)
		} catch {
			savedError = error
		}

		do {
			try await sendStoryStatuses(deleteStarredStatuses, throttle: true, apiCall: caller.unstar)
		} catch {
			savedError = error
		}

		if let savedError {
			throw savedError
		}
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
		Self.logger.info("NewsBlur: Refreshing story statuses")
		defer {
			Self.logger.info("NewsBlur: Finished refreshing article statuses")
		}

		var savedError: Error?

		do {
			let storyHashes = try await caller.retrieveUnreadStoryHashes()
			await syncStoryReadState(account: account, hashes: storyHashes)
		} catch {
			Self.logger.error("NewsBlur: error retrieving unread stories: \(error.localizedDescription)")
			savedError = error
		}

		do {
			let storyHashes = try await caller.retrieveStarredStoryHashes()
			await syncStoryStarredState(account: account, hashes: storyHashes)
		} catch {
			Self.logger.error("NewsBlur: error retrieving starred stories: \(error.localizedDescription)")
			savedError = error
		}

		if let savedError {
			throw savedError
		}
	}

	func refreshStories(for account: Account) async throws {
		Self.logger.info("NewsBlur: Refreshing stories and unread stories")

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
		Self.logger.info("NewsBlur: Refreshing missing stories")
		defer {
			Self.logger.info("NewsBlur: Finished refreshing missing stories.")
		}

		let fetchedArticleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate()

		var savedError: Error?

		let storyHashes = Array(fetchedArticleIDs).map {
			NewsBlurStoryHash(hash: $0, timestamp: Date())
		}
		let chunkedStoryHashes = storyHashes.chunked(into: 100)

		for chunk in chunkedStoryHashes {
			do {
				let (stories, _) = try await caller.retrieveStories(hashes: chunk)
				try await processStories(account: account, stories: stories)
			} catch {
				savedError = error
				Self.logger.error("NewsBlur: Refresh missing stories error: \(error.localizedDescription)")
			}
		}

		if let savedError {
			throw savedError
		}
	}

	@discardableResult
	func processStories(account: Account, stories: [NewsBlurStory]?, since: Date? = nil) async throws -> Bool {
		let parsedItems = mapStoriesToParsedItems(stories: stories).filter {
			guard let datePublished = $0.datePublished, let since else {
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


	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		defer {
			refreshProgress.completeTask()
		}

		try await caller.addFolder(named: name)

		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		guard let folderToRename = folder.name else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
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

	@MainActor func removeFolder(for account: Account, with folder: Folder) async throws {
		guard let folderToRemove = folder.name else {
			throw AccountError.invalidParameter
		}

		var feedIDs: [String] = []
		for feed in folder.topLevelFeeds {
			if (feed.folderRelationship?.count ?? 0) > 1 {
				clearFolderRelationship(for: feed, withFolderName: folderToRemove)
			} else if let feedID = feed.externalID {
				feedIDs.append(feedID)
			}
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		defer {
			refreshProgress.completeTask()
		}

		try await caller.removeFolder(named: folderToRemove, feedIDs: feedIDs)
		account.removeFolderFromTree(folder)
	}

	@discardableResult
	@MainActor func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		defer {
			refreshProgress.completeTask()
		}

		let folderName = (container as? Folder)?.name

		do {
			guard let newsBlurFeed = try await caller.addURL(urlString, folder: folderName) else {
				throw NewsBlurError.unknown
			}
			let feed = try await createFeed(account: account, newsBlurFeed: newsBlurFeed, name: name, container: container)
			return feed
		} catch {
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		guard let feedID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
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

	@MainActor func addFeed(account: Account, feed: Feed, container: Container) async throws {
		if let account = container as? Account {
			account.addFeedToTreeAtTopLevel(feed)
			return
		}

		guard let folder = container as? Folder else {
			return
		}

		let folderName = folder.name ?? ""
		saveFolderRelationship(for: feed, withFolderName: folderName, id: folderName)
		folder.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		try await deleteFeed(for: account, with: feed, from: container)
	}

	@MainActor func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let feedID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		defer {
			refreshProgress.completeTask()
		}

		try await caller.moveFeed(feedID: feedID,
								  from: (sourceContainer as? Folder)?.name,
								  to: (destinationContainer as? Folder)?.name)

		sourceContainer.removeFeedFromTreeAtTopLevel(feed)
		destinationContainer.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws {
		guard let folderName = folder.name else {
			throw AccountError.invalidParameter
		}

		var feedsToRestore: [Feed] = []
		for feed in folder.topLevelFeeds {
			feedsToRestore.append(feed)
			folder.topLevelFeeds.remove(feed)
		}

		do {
			let folder = try await createFolder(for: account, name: folderName)
			for feed in feedsToRestore {
				try await restoreFeed(for: account, feed: feed, container: folder)
			}
		} catch {
			Self.logger.error("NewsBlur: Restore folder error: \(error.localizedDescription)")
			throw error
		}
	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		try await account.update(articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try await syncDatabase.selectPendingCount(), count > 100 {
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

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
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
		syncDatabase.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		caller.resume()
		syncDatabase.resume()
	}
}
