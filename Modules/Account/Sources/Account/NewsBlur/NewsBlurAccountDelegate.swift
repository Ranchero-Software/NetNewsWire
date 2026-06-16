//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import ErrorLog
import RSCore
import RSDatabase
import RSParser
import RSWeb
import NewsBlur
import SyncDatabase
import os
import Secrets

@MainActor final class NewsBlurAccountDelegate: AccountDelegate {
	weak var account: Account?
	var behaviors: AccountBehaviors = []

	var isOPMLImportInProgress: Bool = false
	var server: String? = "newsblur.com"
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	var accountSettings: AccountSettings?

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}
	let refreshProgress = RSProgress()

	let caller: NewsBlurAPICaller
	let syncDatabase: SyncDatabase

	static let logger = NewsBlur.logger

	init(dataFolder: String) {
		caller = NewsBlurAPICaller()

		syncDatabase = SyncDatabase(databasePath: dataFolder.appending("/DB.sqlite3"))
		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .newsBlurSessionID)
		}

		refreshProgress.reset()
		self.refreshProgress.addTasks(4)

		do {
			try await account.logActivity(kind: .refreshAll) {
				try await refreshFeeds(for: account)
				refreshProgress.completeTask()

				try await sendArticleStatus()
				refreshProgress.completeTask()

				try await refreshArticleStatus()
				refreshProgress.completeTask()

				try await refreshMissingStories(for: account)
				refreshProgress.completeTask()

				accountSettings?.lastRefreshCompletedDate = Date()
			}
		} catch {
			refreshProgress.reset()
			throw AccountError.wrapped(error, account)
		}
	}

	@MainActor func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}
		let sentCount = try await sendArticleStatusReturningCount(for: account)
		let refreshChangedCount = try await refreshArticleStatusReturningCount(for: account)
		return sentCount > 0 || refreshChangedCount > 0
	}

	@MainActor func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await sendArticleStatusReturningCount(for: account)
	}

	/// Sends queued local status changes upstream. Returns the count successfully sent.
	@MainActor private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.info("NewsBlur: Sending story statuses")
		defer {
			Self.logger.info("NewsBlur: Finished sending article statuses")
		}

		return try await account.logActivity(kind: .sendArticleStatuses) { () -> Int in
			guard let syncStatuses = await syncDatabase.selectForProcessing() else {
				return 0
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

			var sentCount = 0
			var savedError: Error?

			do {
				sentCount += try await sendStoryStatuses(createUnreadStatuses, throttle: true, apiCall: caller.markAsUnread)
			} catch {
				savedError = error
			}

			do {
				sentCount += try await sendStoryStatuses(deleteUnreadStatuses, throttle: false, apiCall: caller.markAsRead)
			} catch {
				savedError = error
			}

			do {
				sentCount += try await sendStoryStatuses(createStarredStatuses, throttle: true, apiCall: caller.star)
			} catch {
				savedError = error
			}

			do {
				sentCount += try await sendStoryStatuses(deleteStarredStatuses, throttle: true, apiCall: caller.unstar)
			} catch {
				savedError = error
			}

			if let savedError {
				postSyncError(savedError, account: account, operation: "Sending article status")
				throw savedError
			}
			return sentCount
		}
	}

	@MainActor func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await refreshArticleStatusReturningCount(for: account)
	}

	/// Brings local read/starred statuses in line with the server. Returns the count
	/// of articles whose local state actually changed.
	@MainActor private func refreshArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.info("NewsBlur: Refreshing story statuses")
		defer {
			Self.logger.info("NewsBlur: Finished refreshing article statuses")
		}

		return try await account.logActivity(kind: .refreshArticleStatuses) { () -> Int in
			var changedCount = 0
			var savedError: Error?

			do {
				let storyHashes = try await caller.retrieveUnreadStoryHashes()
				changedCount += await syncStoryReadState(account: account, hashes: storyHashes)
			} catch {
				Self.logger.error("NewsBlur: error retrieving unread stories: \(error.localizedDescription)")
				savedError = error
			}

			do {
				let storyHashes = try await caller.retrieveStarredStoryHashes()
				changedCount += await syncStoryStarredState(account: account, hashes: storyHashes)
			} catch {
				Self.logger.error("NewsBlur: error retrieving starred stories: \(error.localizedDescription)")
				savedError = error
			}

			if let savedError {
				postSyncError(savedError, account: account, operation: "Refreshing article status")
				throw savedError
			}
			return changedCount
		}
	}

	func refreshStories(for account: Account) async throws {
		Self.logger.info("NewsBlur: Refreshing stories and unread stories")

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
		Self.logger.info("NewsBlur: Refreshing missing stories")
		defer {
			Self.logger.info("NewsBlur: Finished refreshing missing stories.")
		}

		try await account.logActivity(kind: .refreshMissingArticles) {
			let fetchedArticleIDs = await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()

			var savedError: Error?

			let storyHashes = Array(fetchedArticleIDs).map {
				NewsBlurStoryHash(hash: $0, timestamp: Date())
			}
			let chunkedStoryHashes = storyHashes.chunked(into: 100)

			for chunk in chunkedStoryHashes {
				do {
					let (stories, _) = try await logRefreshPage(for: account, kind: .refreshMissingArticles, message: { "\($0.0?.count ?? 0) articles" }, { try await caller.retrieveStories(hashes: chunk) })
					await processStories(account: account, stories: stories)
				} catch {
					savedError = error
					Self.logger.error("NewsBlur: Refresh missing stories error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Refreshing stories")
				}
			}

			if let savedError {
				throw savedError
			}
		}
	}

	@discardableResult
	func processStories(account: Account, stories: [NewsBlurStory]?, since: Date? = nil) async -> Bool {
		let parsedItems = mapStoriesToParsedItems(stories: stories).filter {
			guard let datePublished = $0.datePublished, let since else {
				return true
			}
			return datePublished >= since
		}
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues {
			Set($0)
		}

		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
		return !feedIDsAndItems.isEmpty
	}

	@MainActor func importOPML(opmlFile: URL) async throws {
	}

	@MainActor func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		return try await account.logActivity(kind: .createFolder, detail: name) {
			try await caller.addFolder(named: name)

			guard let folder = account.ensureFolder(with: name) else {
				throw AccountError.invalidParameter
			}
			return folder
		}
	}

	@MainActor func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		guard let folderToRename = folder.name else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		try await account.logActivity(kind: .renameFolder, detail: "\(folderToRename) → \(name)") {
			let nameBefore = folder.name

			do {
				try await caller.renameFolder(with: folderToRename, to: name)
				folder.name = name
			} catch {
				folder.name = nameBefore
				throw error
			}
		}
	}

	@MainActor func removeFolder(with folder: Folder) async throws {
		guard let account else {
			return
		}
		guard let folderToRemove = folder.name else {
			throw AccountError.invalidParameter
		}

		try await account.logActivity(kind: .removeFolder, detail: folderToRemove) {
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
			account.removeFolderFromTree(folder)
		}
	}

	@discardableResult
	@MainActor func createFeed(url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let folderName = (container as? Folder)?.name

		do {
			return try await account.logActivity(kind: .subscribeFeed, detail: urlString) {
				guard let newsBlurFeed = try await caller.addURL(urlString, folder: folderName) else {
					throw NewsBlurError.unknown
				}
				let feed = try await createFeed(account: account, newsBlurFeed: newsBlurFeed, name: name, container: container)
				return feed
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	@MainActor func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		guard let feedID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				try await caller.renameFeed(feedID: feedID, newName: name)
				feed.editedName = name
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	@MainActor func addFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		account.logActivity(kind: .addFeed, detail: feed.url) {
			if let containerAccount = container as? Account {
				containerAccount.addFeedToTreeAtTopLevel(feed)
				return
			}

			guard let folder = container as? Folder else {
				return
			}

			let folderName = folder.name ?? ""
			saveFolderRelationship(for: feed, withFolderName: folderName, id: folderName)
			folder.addFeedToTreeAtTopLevel(feed)
		}
	}

	@MainActor func removeFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .removeFeed, detail: feed.url) {
			try await deleteFeed(for: account, with: feed, from: container)
		}
	}

	@MainActor func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		guard let feedID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		try await account.logActivity(kind: .moveFeed, detail: feed.url) {
			try await caller.moveFeed(feedID: feedID,
									  from: (sourceContainer as? Folder)?.name,
									  to: (destinationContainer as? Folder)?.name)

			sourceContainer.removeFeedFromTreeAtTopLevel(feed)
			destinationContainer.addFeedToTreeAtTopLevel(feed)
		}
	}

	@MainActor func restoreFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			try await createFeed(url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	@MainActor func restoreFolder(folder: Folder) async throws {
		guard let account else {
			return
		}
		guard let folderName = folder.name else {
			throw AccountError.invalidParameter
		}

		var feedsToRestore: [Feed] = []
		for feed in folder.topLevelFeeds {
			feedsToRestore.append(feed)
			folder.topLevelFeeds.remove(feed)
		}

		do {
			try await account.logActivity(kind: .restoreFolder, detail: folderName) {
				let folder = try await createFolder(name: folderName)
				for feed in feedsToRestore {
					try await restoreFeed(feed: feed, container: folder)
				}
			}
		} catch {
			Self.logger.error("NewsBlur: Restore folder error: \(error.localizedDescription)")
			postSyncError(error, account: account, operation: "Restoring folder")
			throw error
		}
	}

	@MainActor func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		guard let account else {
			return
		}
		_ = await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articleIDs.map { articleID in
			SyncStatus(articleID: articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		await syncDatabase.insertStatuses(syncStatuses)
		if !syncStatuses.isEmpty {
			NotificationCenter.default.post(name: .AccountDidQueueArticleStatuses, object: account)
		}
		if let count = await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus()
		}
	}

	func accountDidInitialize() {
		credentials = try? account?.retrieveCredentials(type: .newsBlurSessionID)
	}

	func accountWillBeDeleted() {
		guard let account else {
			return
		}
		Task { @MainActor in
			try? await account.logActivity(kind: .validateCredentials, detail: "Logging out of NewsBlur") {
				try await caller.logout()
			}
		}
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		let caller = NewsBlurAPICaller()
		caller.credentials = credentials
		return try await caller.validateCredentials()
	}

	func vacuumDatabases() async {
		guard let account else {
			return
		}
		await account.logActivity(kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(syncDatabase.databasePath)) {
			await syncDatabase.vacuum()
		}
	}

	// MARK: - Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Resume network activity after a previous `suspendNetwork()`.
	func resume() {
		if let account, credentials == nil {
			credentials = try? account.retrieveCredentials(type: .newsBlurSessionID)
		}
		caller.resume()
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: - Sync Error Posting

extension NewsBlurAccountDelegate {

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}
