//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ActivityLog
import Articles
import ErrorLog
import FeedFinder
import RSCore
import RSDatabase
import RSParser
import RSWeb
import SyncDatabase
import os
import Secrets

public enum FeedbinAccountDelegateError: String, Error, Sendable {
	case invalidParameter = "There was an invalid parameter passed."
	case unknown = "An unknown error occurred."
}

@MainActor final class FeedbinAccountDelegate: AccountDelegate {
	weak var account: Account?
	let behaviors: AccountBehaviors = [.disallowFeedCopyInRootFolder]
	let server: String? = "api.feedbin.com"
	var isOPMLImportInProgress = false

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}
	let refreshProgress = RSProgress()

	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	var accountSettings: AccountSettings? {
		didSet {
			caller.accountSettings = accountSettings
		}
	}

	private let syncDatabase: SyncDatabase
	private let caller: FeedbinAPICaller
	private var articlesRefreshedCount = 0
	private static let logger = Feedbin.logger

	init(dataFolder: String) {
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databaseFilePath)
		caller = FeedbinAPICaller()

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refreshProgress)
	}

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	func refreshAll() async throws {
		guard let account else {
			return
		}
		if credentials == nil {
			credentials = try? account.retrieveCredentials(type: .basic)
		}

		refreshProgress.reset()
		refreshProgress.addTasks(5)

		do {
			try await account.logActivity(kind: .refreshAll) {
				try await refreshAccount(account)
				try await refreshArticlesAndStatuses(account)
			}
		} catch {
			refreshProgress.reset()
			throw AccountError.wrapped(error, account)
		}
	}

	func syncArticleStatus() async throws -> Bool {
		guard let account else {
			return false
		}
		let sentCount = try await sendArticleStatusReturningCount(for: account)
		let refreshChangedCount = try await refreshArticleStatusReturningCount(for: account)
		return sentCount > 0 || refreshChangedCount > 0
	}

	func sendArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await sendArticleStatusReturningCount(for: account)
	}

	/// Sends queued local status changes upstream. Returns the count successfully sent.
	private func sendArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.info("Feedbin: Sending article statuses")
		defer {
			Self.logger.info("Feedbin: Finished sending article statuses")
		}

		do {
			return try await account.logActivity(kind: .sendArticleStatuses) { () -> Int in
				guard let syncStatuses = await syncDatabase.selectForProcessing() else {
					return 0
				}

				var sentCount = 0

				let createUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false })
				sentCount += try await sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries)

				let deleteUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true })
				sentCount += try await sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries)

				let createStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true })
				sentCount += try await sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries)

				let deleteStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false })
				sentCount += try await sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries)

				return sentCount
			}
		} catch {
			postSyncError(error, account: account, operation: "Sending article status")
			throw error
		}
	}

	func refreshArticleStatus() async throws {
		guard let account else {
			return
		}
		_ = try await refreshArticleStatusReturningCount(for: account)
	}

	/// Brings local read/starred statuses in line with the server. Returns the count
	/// of articles whose local state actually changed.
	private func refreshArticleStatusReturningCount(for account: Account) async throws -> Int {
		Self.logger.info("Feedbin: Refreshing article statuses")

		return try await account.logActivity(kind: .refreshArticleStatuses) { () -> Int in
			var changedCount = 0
			var refreshError: Error?

			do {
				let articleIDs = try await caller.retrieveUnreadEntries()
				changedCount += await self.syncArticleReadState(account: account, articleIDs: articleIDs)
			} catch {
				refreshError = error
				Self.logger.error("Feedbin: Retrieving unread entries failed: \(error.localizedDescription)")
			}

			do {
				let articleIDs = try await caller.retrieveStarredEntries()
				changedCount += await self.syncArticleStarredState(account: account, articleIDs: articleIDs)
			} catch {
				refreshError = error
				Self.logger.error("Feedbin: Retrieving starred entries failed: \(error.localizedDescription)")
			}

			Self.logger.info("Feedbin: Finished refreshing article statuses")
			if let refreshError {
				postSyncError(refreshError, account: account, operation: "Refreshing article status")
				throw refreshError
			}
			return changedCount
		}
	}

	func importOPML(opmlFile: URL) async throws {
		guard let account else {
			return
		}
		let opmlData = try Data(contentsOf: opmlFile)
		guard !opmlData.isEmpty else {
			return
		}

		Self.logger.info("Feedbin: Did begin importing OPML")
		isOPMLImportInProgress = true
		refreshProgress.addTask()
		defer {
			isOPMLImportInProgress = false
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .importOPML, detail: opmlFile.lastPathComponent) {
				let importResult = try await caller.importOPML(opmlData: opmlData)
				if importResult.complete {
					Self.logger.info("Feedbin: Finished importing OPML")
				} else {
					// This will retry until success or error.
					try await self.checkImportResult(opmlImportResultID: importResult.importResultID)
				}
			}
		} catch {
			Self.logger.info("Feedbin: OPML import failed: \(error.localizedDescription)")
			throw AccountError.wrapped(error, account)
		}
	}

	func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	func renameFolder(with folder: Folder, to name: String) async throws {
		guard let account else {
			return
		}
		guard folder.hasAtLeastOneFeed() else {
			folder.name = name
			return
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .renameFolder, detail: folder.name) {
				try await caller.renameTag(oldName: folder.name ?? "", newName: name)
				renameFolderRelationship(for: account, fromName: folder.name ?? "", toName: name)
				folder.name = name
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFolder(with folder: Folder) async throws {
		guard let account else {
			return
		}
		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.removeFolderFromTree(folder)
			return
		}

		refreshProgress.addTasks(folder.topLevelFeeds.count)

		for feed in folder.topLevelFeeds {
			defer {
				refreshProgress.completeTask()
			}

			if feed.folderRelationship?.count ?? 0 > 1 {
				if let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
					do {
						try await caller.deleteTagging(taggingID: feedTaggingID)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					} catch {
						Self.logger.error("Feedbin: Remove feed error: \(error.localizedDescription)")
						postSyncError(error, account: account, operation: "Removing feed")
					}
				}
			} else {
				if let subscriptionID = feed.externalID {
					do {
						try await caller.deleteSubscription(subscriptionID: subscriptionID)
						account.clearFeedSettings(feed)
					} catch {
						Self.logger.error("Feedbin: Remove feed error: \(error.localizedDescription)")
						postSyncError(error, account: account, operation: "Removing feed")
					}
				}
			}
		}

		account.removeFolderFromTree(folder)
	}

	@discardableResult
	func createFeed(url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			return try await account.logActivity(kind: .subscribeFeed, detail: urlString) {
				let subResult = try await caller.createSubscription(url: urlString)
				switch subResult {
				case .created(let subscription):
					return try await createFeed(account: account, subscription: subscription, name: name, container: container)
				case .multipleChoice(let choices):
					return try await decideBestFeedChoice(account: account, url: urlString, name: name, container: container, choices: choices)
				case .alreadySubscribed:
					throw AccountError.createErrorAlreadySubscribed
				case .notFound:
					throw AccountError.createErrorNotFound
				}
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func renameFeed(with feed: Feed, to name: String) async throws {
		guard let account else {
			return
		}
		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		do {
			try await account.logActivity(kind: .renameFeed, detail: feed.url) {
				try await caller.renameSubscription(subscriptionID: subscriptionID, newName: name)
				feed.editedName = name
			}
		} catch {
			throw AccountError.wrapped(error, account)
		}
	}

	func removeFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .removeFeed, detail: feed.url) {
			if feed.folderRelationship?.count ?? 0 > 1 {
				try await deleteTagging(for: account, with: feed, from: container)
			} else {
				try await deleteSubscription(for: account, with: feed, from: container)
			}
		}
	}

	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .moveFeed, detail: feed.url) {
			if sourceContainer is Account {
				try await addFeed(feed: feed, container: destinationContainer)
			} else {
				try await deleteTagging(for: account, with: feed, from: sourceContainer)
				try await addFeed(feed: feed, container: destinationContainer)
			}
		}
	}

	func addFeed(feed: Feed, container: Container) async throws {
		guard let account else {
			return
		}
		try await account.logActivity(kind: .addFeed, detail: feed.url) {
			if let folder = container as? Folder, let feedID = Int(feed.feedID) {

				refreshProgress.addTask()
				defer { refreshProgress.completeTask() }

				do {
					let taggingID = try await caller.createTagging(feedID: feedID, name: folder.name ?? "")

					saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
					account.removeFeedFromTreeAtTopLevel(feed)
					folder.addFeedToTreeAtTopLevel(feed)
				} catch {
					throw AccountError.wrapped(error, account)
				}
			} else if let containerAccount = container as? Account {
				containerAccount.addFeedIfNotInAnyFolder(feed)
			}
		}
	}

	func restoreFeed(feed: Feed, container: any Container) async throws {
		guard let account else {
			return
		}
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			try await account.addFeed(existingFeed, container: container)
		} else {
			try await createFeed(url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		}
	}

	func restoreFolder(folder: Folder) async throws {
		guard let account else {
			return
		}
		await account.logActivity(kind: .restoreFolder, detail: folder.name ?? "") {
			for feed in folder.topLevelFeeds {

				folder.topLevelFeeds.remove(feed)

				do {
					try await restoreFeed(feed: feed, container: folder)
				} catch {
					Self.logger.error("Feedbin: Restore folder feed error: \(error.localizedDescription)")
					postSyncError(error, account: account, operation: "Restoring feed")
				}
			}

			account.addFolderToTree(folder)
		}
	}

	func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		guard let account else {
			return
		}
		let changedArticleIDs = await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(changedArticleIDs.map { articleID in
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
		credentials = try? account?.retrieveCredentials(type: .basic)
	}

	func accountWillBeDeleted() {
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		let caller = FeedbinAPICaller()
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

	// MARK: Suspend and Resume

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Resume network activity after a previous `suspendNetwork()`.
	func resume() {
		if let account, credentials == nil {
			credentials = try? account.retrieveCredentials(type: .basic)
		}
		caller.resume()
	}

	// MARK: - Notifications
	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refreshProgress.progressInfo
	}
}

// MARK: Private

private extension FeedbinAccountDelegate {

	func checkImportResult(opmlImportResultID: Int) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.checkImportResult(opmlImportResultID: opmlImportResultID) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func checkImportResult(opmlImportResultID: Int, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			while true {
				try? await Task.sleep(for: .seconds(15))

				Self.logger.info("Feedbin: Checking status of OPML import")
				do {
					let importResult = try await self.caller.retrieveOPMLImportResult(importID: opmlImportResultID)

					if let result = importResult, result.complete {
						Self.logger.info("Feedbin: Checking status of OPML import finished successfully")
						self.refreshProgress.completeTask()
						self.isOPMLImportInProgress = false
						completion(.success(()))
						break
					}
				} catch {
					Self.logger.info("Feedbin: Import OPML check failed: \(error.localizedDescription)")
					self.refreshProgress.completeTask()
					self.isOPMLImportInProgress = false
					completion(.failure(error))
					break
				}
			}
		}
	}

	func refreshAccount(_ account: Account) async throws {
		do {
			try await account.logActivity(kind: .refreshFeedList, successMessage: { "\($0.feeds) feeds, \($0.folders) folders" }, { () -> (folders: Int, feeds: Int) in
				let tags = try await self.caller.retrieveTags()
				self.refreshProgress.completeTask()

				let subscriptions = try await self.caller.retrieveSubscriptions()
				self.refreshProgress.completeTask()
				self.forceExpireFolderFeedRelationship(account, tags)

				let taggings = try await self.caller.retrieveTaggings()
				BatchUpdate.shared.perform {
					self.syncFolders(account, tags)
					self.syncFeeds(account, subscriptions)
					self.syncFeedFolderRelationship(account, taggings)
				}
				self.refreshProgress.completeTask()
				return (folders: tags?.count ?? 0, feeds: subscriptions?.count ?? 0)
			})
		} catch {
			postSyncError(error, account: account, operation: "Refreshing account")
			throw error
		}
	}

	func refreshArticlesAndStatuses(_ account: Account) async throws {
		try await sendArticleStatus()
		try await refreshArticleStatus()
		try await refreshArticles(account)
		try await refreshMissingArticles(account)
		refreshProgress.reset()
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
				accountSettings?.setConditionalGetInfo(nil, for: FeedbinAPICaller.ConditionalGetKeys.taggings)
			}
		}
	}

	func syncFolders(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing folders \(tags.count) tags")

		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
		if let folders = account.folders {
			for folder in folders {
				if !tagNames.contains(folder.name ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeedToTreeAtTopLevel(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolderFromTree(folder)
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

		Self.logger.info("Feedbin: Syncing feeds with \(subscriptions.count) subscriptions")

		let subFeedIds = subscriptions.map { String($0.feedID) }

		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						folder.removeFeedFromTreeAtTopLevel(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		var subscriptionsToAdd = Set<FeedbinSubscription>()
		for subscription in subscriptions {
			let subFeedId = String(subscription.feedID)

			if let feed = account.existingFeed(withFeedID: subFeedId) {
				feed.name = subscription.name
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
				feed.externalID = String(subscription.subscriptionID)
				feed.faviconURL = subscription.jsonFeed?.favicon
				feed.iconURL = subscription.jsonFeed?.icon
			} else {
				subscriptionsToAdd.insert(subscription)
			}
		}

		// Actually add subscriptions all in one go, so we don’t trigger various rebuilding things that Account does.
		for subscription in subscriptionsToAdd {
			let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
			feed.externalID = String(subscription.subscriptionID)
			account.addFeedToTreeAtTopLevel(feed)
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ taggings: [FeedbinTagging]?) {

		guard let taggings = taggings else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing taggings with \(taggings.count) taggings")

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
					folder.removeFeedFromTreeAtTopLevel(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addFeedToTreeAtTopLevel(feed)
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
					folder.addFeedToTreeAtTopLevel(feed)
				}
			}

		}

		let taggedFeedIDs = Set(taggings.map { String($0.feedID) })

		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeedFromTreeAtTopLevel(feed)
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

	func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([Int]) async throws -> Void) async throws -> Int {
		guard !statuses.isEmpty else {
			return 0
		}

		var savedError: Error?
		var sentCount = 0

		let articleIDs = statuses.compactMap { Int($0.articleID) }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {
			do {
				try await apiCall(articleIDGroup)
				await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup.map { String($0) }))
				sentCount += articleIDGroup.count
			} catch {
				savedError = error
				Self.logger.error("Feedbin: Article status sync call failed: \(error.localizedDescription)")
				await self.syncDatabase.resetSelectedForProcessing(Set(articleIDGroup.map { String($0) }))
			}
		}

		if let savedError {
			throw savedError
		}
		return sentCount
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
			let source = url == choice.url ? FeedSpecifier.Source.userEntered : FeedSpecifier.Source.HTMLLink
			orderFound += 1
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source, orderFound: orderFound)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			let feed = try await createFeed(url: bestSpecifier.urlString, name: name, container: container, validateFeed: true)
			return feed
		} else {
			throw AccountError.invalidParameter
		}
	}

	@discardableResult
	func createFeed(account: Account, subscription: FeedbinSubscription, name: String?, container: Container) async throws -> Feed {
		let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
		feed.externalID = String(subscription.subscriptionID)
		feed.iconURL = subscription.jsonFeed?.icon
		feed.faviconURL = subscription.jsonFeed?.favicon

		try await account.addFeed(feed, container: container)
		if let name {
			try await account.renameFeed(feed, name: name)
		}

		Task {
			try? await initialFeedDownload(account: account, feed: feed)
		}

		return feed
	}

	func initialFeedDownload(account: Account, feed: Feed) async throws -> Feed {
		// Download the initial articles
		let (entries, page) = try await caller.retrieveEntries(feedID: feed.feedID)
		await processEntries(account: account, entries: entries)
		try await refreshArticleStatus()
		try await refreshArticles(account, page: page, updateFetchDate: nil)
		try await refreshMissingArticles(account)

		return feed
	}

	func refreshArticles(_ account: Account) async throws {
		Self.logger.info("Feedbin: Refreshing articles")

		do {
			articlesRefreshedCount = 0
			try await account.logActivity(kind: .refreshArticles, successMessage: { _ in "\(self.articlesRefreshedCount) articles" }, {
				let (entries, page, updateFetchDate, lastPageNumber) = try await self.refreshArticlesPage(for: account, articleCount: { $0.0?.count ?? 0 }, { try await self.caller.retrieveEntries() })

				if let last = lastPageNumber {
					self.refreshProgress.addTasks(last - 1)
				}

				self.articlesRefreshedCount += entries?.count ?? 0
				await self.processEntries(account: account, entries: entries)
				self.refreshProgress.completeTask()

				try await self.refreshArticles(account, page: page, updateFetchDate: updateFetchDate)
			})
		} catch {
			postSyncError(error, account: account, operation: "Refreshing articles")
			throw error
		}
	}

	func refreshMissingArticles(_ account: Account) async throws {
		Self.logger.info("Feedbin: Refreshing missing articles")
		defer {
			refreshProgress.completeTask()
			Self.logger.info("Feedbin: Finished refreshing missing articles")
		}

		try await account.logActivity(kind: .refreshMissingArticles) {
			var savedError: Error?

			let fetchedArticleIDs = await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
			let articleIDs = Array(fetchedArticleIDs)
			let chunkedArticleIDs = articleIDs.chunked(into: 100)

			for chunk in chunkedArticleIDs {
				do {
					let entries = try await caller.retrieveEntries(articleIDs: chunk)
					await processEntries(account: account, entries: entries)
				} catch {
					savedError = error
					Self.logger.error("Feedbin: Refresh missing articles error: \(error.localizedDescription)")
				}
			}

			if let savedError {
				postSyncError(savedError, account: account, operation: "Refreshing missing articles")
				throw savedError
			}
		}
	}

	func refreshArticles(_ account: Account, page: String?, updateFetchDate: Date?) async throws {
		guard let page else {
			if let lastArticleFetch = updateFetchDate {
				accountSettings?.lastArticleFetchStartTime = lastArticleFetch
				accountSettings?.lastRefreshCompletedDate = Date()
			}
			return
		}

		let (entries, nextPage) = try await refreshArticlesPage(for: account, articleCount: { $0.0?.count ?? 0 }, { try await caller.retrieveEntries(page: page) })

		articlesRefreshedCount += entries?.count ?? 0
		await processEntries(account: account, entries: entries)
		refreshProgress.completeTask()

		try await refreshArticles(account, page: nextPage, updateFetchDate: updateFetchDate)
	}

	/// Fetches one page of the article refresh as its own numbered, timed sub-activity,
	/// reporting the page's article count — the per-page detail under the parent
	/// `.refreshArticles` activity.
	private func refreshArticlesPage<T>(for account: Account, articleCount: @escaping (T) -> Int, _ fetch: () async throws -> T) async throws -> T {
		try await account.logActivity(kind: .refreshArticles, detail: ActivityLog.shared.nextTaskNumberString(), successMessage: { "\(articleCount($0)) articles" }, fetch)
	}

	func processEntries(account: Account, entries: [FeedbinEntry]?) async {
		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues { Set($0) }
		await account.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
	}

	func mapEntriesToParsedItems(entries: [FeedbinEntry]?) -> Set<ParsedItem> {
		guard let entries = entries else {
			return Set<ParsedItem>()
		}

		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			return ParsedItem(syncServiceID: String(entry.articleID), uniqueID: String(entry.articleID), feedURL: String(entry.feedID), url: entry.url, externalURL: entry.jsonFeed?.jsonFeedExternalURL, title: entry.title, language: nil, contentHTML: entry.contentHTML, contentText: nil, markdown: nil, summary: entry.summary, imageURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: nil)
		}

		return Set(parsedItems)

	}

	func syncArticleReadState(account: Account, articleIDs: [Int]?) async -> Int {
		guard let articleIDs else {
			return 0
		}

		guard let pendingArticleIDs = await syncDatabase.selectPendingReadStatusArticleIDs() else {
			return 0
		}

		let feedbinUnreadArticleIDs = Set(articleIDs.map { String($0) })
		let updatableFeedbinUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(pendingArticleIDs)

		let currentUnreadArticleIDs = await account.fetchUnreadArticleIDsAsync()

		// Mark articles as unread
		let deltaUnreadArticleIDs = updatableFeedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
		let markedUnread = await account.markAsUnreadAsync(articleIDs: deltaUnreadArticleIDs)

		// Mark articles as read
		let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableFeedbinUnreadArticleIDs)
		let markedRead = await account.markAsReadAsync(articleIDs: deltaReadArticleIDs)

		return markedUnread.count + markedRead.count
	}

	func syncArticleStarredState(account: Account, articleIDs: [Int]?) async -> Int {
		guard let articleIDs else {
			return 0
		}

		guard let pendingArticleIDs = await syncDatabase.selectPendingStarredStatusArticleIDs() else {
			return 0
		}

		let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) })
		let updatableFeedbinStarredArticleIDs = feedbinStarredArticleIDs.subtracting(pendingArticleIDs)

		let currentStarredArticleIDs = await account.fetchStarredArticleIDsAsync()

		// Mark articles as starred
		let deltaStarredArticleIDs = updatableFeedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
		let markedStarred = await account.markAsStarredAsync(articleIDs: deltaStarredArticleIDs)

		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableFeedbinStarredArticleIDs)
		let markedUnstarred = await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)

		return markedStarred.count + markedUnstarred.count
	}

	func deleteTagging(for account: Account, with feed: Feed, from container: Container?) async throws {
		if let folder = container as? Folder, let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
			refreshProgress.addTask()
			defer {
				refreshProgress.completeTask()
			}

			do {
				try await caller.deleteTagging(taggingID: feedTaggingID)
				clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
				folder.removeFeedFromTreeAtTopLevel(feed)
				account.addFeedIfNotInAnyFolder(feed)
			} catch {
				throw AccountError.wrapped(error, account)
			}
		} else {
			if let account = container as? Account {
				account.removeFeedFromTreeAtTopLevel(feed)
			}
		}
	}

	func deleteSubscription(for account: Account, with feed: Feed, from container: Container?) async throws {
		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			throw AccountError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await caller.deleteSubscription(subscriptionID: subscriptionID)
		} catch {
			Self.logger.error("Feedbin: Unable to remove feed from Feedbin. Removing locally and continuing processing: \(error.localizedDescription)")
			postSyncError(error, account: account, operation: "Removing feed")
		}

		account.clearFeedSettings(feed)
		account.removeAllInstancesOfFeedFromTreeAtAllLevels(feed)
	}

	func postSyncError(_ error: Error, account: Account, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}
