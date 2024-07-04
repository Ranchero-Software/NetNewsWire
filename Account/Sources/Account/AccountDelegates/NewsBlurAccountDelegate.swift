//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Core
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
		
		refreshProgress.addTasks(4)

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
			refreshProgress.addTasks((count - 1) / 100 + 1)
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

extension NewsBlurAccountDelegate {

	func refreshFeeds(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing feeds…")

		let (feeds, folders) = try await caller.retrieveFeeds()

		BatchUpdate.shared.perform {
			self.syncFolders(account, folders)
			self.syncFeeds(account, feeds)
			self.syncFeedFolderRelationship(account, folders)
		}
	}

	func syncFolders(_ account: Account, _ folders: [NewsBlurFolder]?) {

		guard let folders else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing folders with %ld folders.", folders.count)

		let folderNames = folders.map { $0.name }

		// Delete any folders not at NewsBlur
		if let folders = account.folders {
			for folder in folders {
				if !folderNames.contains(folder.name ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolder(folder: folder)
				}
			}
		}

		let accountFolderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders NewsBlur has, but we don't
		// Ignore account-level folder
		for folderName in folderNames {
			if !accountFolderNames.contains(folderName) && folderName != " " {
				_ = account.ensureFolder(with: folderName)
			}
		}
	}

	func syncFeeds(_ account: Account, _ feeds: [NewsBlurFeed]?) {
		guard let feeds else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing feeds with %ld feeds.", feeds.count)

		let newsBlurFeedIDs = feeds.map { String($0.feedID) }

		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !newsBlurFeedIDs.contains(feed.feedID) {
						folder.removeFeed(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !newsBlurFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		var feedsToAdd = Set<NewsBlurFeed>()
		feeds.forEach { feed in
			let subFeedID = String(feed.feedID)

			if let feed = account.existingFeed(withFeedID: subFeedID) {
				feed.name = feed.name
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = feed.homePageURL
				feed.externalID = String(feed.feedID)
				feed.faviconURL = feed.faviconURL
			}
			else {
				feedsToAdd.insert(feed)
			}
		}

		// Actually add feeds all in one go, so we don’t trigger various rebuilding things that Account does.
		for feed in feedsToAdd {
			let feed = account.createFeed(with: feed.name, url: feed.feedURL, feedID: String(feed.feedID), homePageURL: feed.homePageURL)
			feed.externalID = String(feed.feedID)
			account.addFeed(feed)
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ folders: [NewsBlurFolder]?) {

		guard let folders else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing folders with %ld folders.", folders.count)

		// Set up some structures to make syncing easier
		let relationships = folders.map({ $0.asRelationships }).flatMap { $0 }
		let folderDict = nameToFolderDictionary(with: account.folders)
		let newsBlurFolderDict = relationships.reduce([String: [NewsBlurFolderRelationship]]()) { (dict, relationship) in
			var feedInFolders = dict
			if var feedInFolder = feedInFolders[relationship.folderName] {
				feedInFolder.append(relationship)
				feedInFolders[relationship.folderName] = feedInFolder
			} else {
				feedInFolders[relationship.folderName] = [relationship]
			}
			return feedInFolders
		}

		// Sync the folders
		for (folderName, folderRelationships) in newsBlurFolderDict {
			guard folderName != " " else {
				continue
			}

			let newsBlurFolderFeedIDs = folderRelationships.map { String($0.feedID) }

			guard let folder = folderDict[folderName] else { return }

			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !newsBlurFolderFeedIDs.contains(feed.feedID) {
					folder.removeFeed(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addFeed(feed)
				}
			}

			// Add any feeds not in the folder
			let folderFeedIDs = folder.topLevelFeeds.map { $0.feedID }

			for relationship in folderRelationships {
				let folderFeedID = String(relationship.feedID)
				if !folderFeedIDs.contains(folderFeedID) {
					guard let feed = account.existingFeed(withFeedID: folderFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: relationship.folderName)
					folder.addFeed(feed)
				}
			}
		}

		// Handle the account level feeds.  If there isn't the special folder, that means all the feeds are
		// in folders and we need to remove them all from the account level.
		if let folderRelationships = newsBlurFolderDict[" "] {
			let newsBlurFolderFeedIDs = folderRelationships.map { String($0.feedID) }
			for feed in account.topLevelFeeds {
				if !newsBlurFolderFeedIDs.contains(feed.feedID) {
					account.removeFeed(feed)
				}
			}
		} else {
			for feed in account.topLevelFeeds {
				account.removeFeed(feed)
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

	func refreshUnreadStories(for account: Account, hashes: [NewsBlurStoryHash]?, updateFetchDate: Date?) async throws {

		guard let hashes, !hashes.isEmpty else {
			if let lastArticleFetch = updateFetchDate {
				self.accountMetadata?.lastArticleFetchStartTime = lastArticleFetch
				self.accountMetadata?.lastArticleFetchEndTime = Date()
			}
			return
		}

		let numberOfStories = min(hashes.count, 100) // api limit
		let hashesToFetch = Array(hashes[..<numberOfStories])

		let (stories, date) = try await caller.retrieveStories(hashes: hashesToFetch)
		try await processStories(account: account, stories: stories)
		try await refreshUnreadStories(for: account, hashes: Array(hashes[numberOfStories...]), updateFetchDate: date)
		os_log(.debug, log: self.log, "Done refreshing stories.")
	}

	func mapStoriesToParsedItems(stories: [NewsBlurStory]?) -> Set<ParsedItem> {
		guard let stories = stories else { return Set<ParsedItem>() }

		let parsedItems: [ParsedItem] = stories.map { story in
			let author = Set([ParsedAuthor(name: story.authorName, url: nil, avatarURL: nil, emailAddress: nil)])
			return ParsedItem(syncServiceID: story.storyID, uniqueID: String(story.storyID), feedURL: String(story.feedID), url: story.url, externalURL: nil, title: story.title, language: nil, contentHTML: story.contentHTML, contentText: nil, summary: nil, imageURL: story.imageURL, bannerImageURL: nil, datePublished: story.datePublished, dateModified: nil, authors: author, tags: Set(story.tags ?? []), attachments: nil)
		}

		return Set(parsedItems)
	}

	func sendStoryStatuses(_ statuses: Set<SyncStatus>, throttle: Bool, apiCall: (Set<String>) async throws -> Void) async throws {

		guard !statuses.isEmpty else {
			return
		}

		var errorOccurred = false

		let storyHashes = statuses.compactMap { $0.articleID }
		let storyHashGroups = storyHashes.chunked(into: throttle ? 1 : 5) // api limit
		for storyHashGroup in storyHashGroups {

			do {
				try await apiCall(Set(storyHashGroup))
			} catch {
				errorOccurred = true
				os_log(.error, log: self.log, "Story status sync call failed: %@.", error.localizedDescription)
				try? await syncDatabase.resetSelectedForProcessing(Set(storyHashGroup))
			}
		}

		if errorOccurred {
			throw NewsBlurError.unknown
		}
	}

	func syncStoryReadState(account: Account, hashes: Set<NewsBlurStoryHash>?) async {

		guard let hashes else {
			return
		}

		do {
			let pendingArticleIDs = (try await syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()

			let newsBlurUnreadStoryHashes = Set(hashes.map { $0.hash } )
			let updatableNewsBlurUnreadStoryHashes = newsBlurUnreadStoryHashes.subtracting(pendingArticleIDs)

			guard let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDs() else {
				return
			}

			// Mark articles as unread
			let deltaUnreadArticleIDs = updatableNewsBlurUnreadStoryHashes.subtracting(currentUnreadArticleIDs)
			try? await account.markAsUnread(deltaUnreadArticleIDs)

			// Mark articles as read
			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableNewsBlurUnreadStoryHashes)
			try? await account.markAsRead(deltaReadArticleIDs)
		} catch {
			os_log(.error, log: self.log, "Sync Story Read Status failed: %@.", error.localizedDescription)
		}
	}

	func syncStoryStarredState(account: Account, hashes: Set<NewsBlurStoryHash>?) async {

		guard let hashes else {
			return
		}

		do {
			let pendingArticleIDs = (try await syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()

			let newsBlurStarredStoryHashes = Set(hashes.map { $0.hash } )
			let updatableNewsBlurUnreadStoryHashes = newsBlurStarredStoryHashes.subtracting(pendingArticleIDs)

			guard let currentStarredArticleIDs = try await account.fetchStarredArticleIDs() else {
				return
			}

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableNewsBlurUnreadStoryHashes.subtracting(currentStarredArticleIDs)
			try? await account.markAsStarred(deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableNewsBlurUnreadStoryHashes)
			try? await account.markAsUnstarred(deltaUnstarredArticleIDs)
		} catch {
			os_log(.error, log: self.log, "Sync Story Starred Status failed: %@.", error.localizedDescription)
		}
	}

	func createFeed(account: Account, newsBlurFeed: NewsBlurFeed, name: String?, container: Container) async throws -> Feed {

		let feed = account.createFeed(with: newsBlurFeed.name, url: newsBlurFeed.feedURL, feedID: String(newsBlurFeed.feedID), homePageURL: newsBlurFeed.homePageURL)
		feed.externalID = String(newsBlurFeed.feedID)
		feed.faviconURL = newsBlurFeed.faviconURL

		try await account.addFeed(feed, to: container)
		if let name {
			try await renameFeed(for: account, with: feed, to: name)
		}
		try await initialFeedDownload(account: account, feed: feed)
		return feed
	}

	func downloadFeed(account: Account, feed: Feed, page: Int) async throws {

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let (stories, _) = try await caller.retrieveStories(feedID: feed.feedID, page: page)
		refreshProgress.completeTask()

		guard let stories, stories.count > 0 else {
			return
		}

		let since: Date? = Calendar.current.date(byAdding: .month, value: -3, to: Date())

		let hasStories = try await processStories(account: account, stories: stories, since: since)
		if hasStories {
			try await downloadFeed(account: account, feed: feed, page: page + 1)
		}
	}

	func initialFeedDownload(account: Account, feed: Feed) async throws {

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		// Download the initial articles
		try await downloadFeed(account: account, feed: feed, page: 1)
		try await refreshArticleStatus(for: account)
		try await refreshMissingStories(for: account)
	}

	func deleteFeed(for account: Account, with feed: Feed, from container: Container?) async throws {

		// This error should never happen
		guard let feedID = feed.externalID else {
			throw NewsBlurError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let folderName = (container as? Folder)?.name

		do {
			try await caller.deleteFeed(feedID: feedID, folder: folderName)

			if folderName == nil {
				account.removeFeed(feed)
			}

			if let folders = account.folders {
				for folder in folders where folderName != nil && folder.name == folderName {
					folder.removeFeed(feed)
				}
			}

			if account.existingFeed(withFeedID: feed.feedID) != nil {
				account.clearFeedMetadata(feed)
			}

		} catch {
			throw AccountError.wrappedError(error: error, account: account)
		}
	}
}

