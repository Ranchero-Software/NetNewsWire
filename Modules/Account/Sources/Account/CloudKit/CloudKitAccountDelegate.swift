//
//  CloudKitAppDelegate.swift
//  Account
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import SystemConfiguration
import os.log
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import Articles
import ArticlesDatabase
import Secrets
import CloudKitSync
import FeedFinder

enum CloudKitAccountDelegateError: LocalizedError, Sendable {
	case invalidParameter
	case unknown

	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

@MainActor final class CloudKitAccountDelegate: AccountDelegate {
	nonisolated private static let logger = cloudKitLogger

	private let syncDatabase: SyncDatabase

	private let container: CKContainer = {
		let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as! String
		return CKContainer(identifier: "iCloud.\(orgID).NetNewsWire")
	}()

	private let accountZone: CloudKitAccountZone
	private let articlesZone: CloudKitArticlesZone

	private let mainThreadOperationQueue = MainThreadOperationQueue()
	private let refresher: LocalAccountRefresher

	weak var account: Account?

	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false

	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	private let syncProgress = RSProgress()
	private var syncProgressInfo = ProgressInfo() {
		didSet {
			updateProgress()
		}
	}

	private var refreshProgressInfo = ProgressInfo() {
		didSet {
			updateProgress()
		}
	}

	init(dataFolder: String) {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		self.accountZone = CloudKitAccountZone(container: container)
		self.articlesZone = CloudKitArticlesZone(container: container)

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		self.refresher = LocalAccountRefresher()
		self.refresher.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .progressInfoDidChange, object: refresher)
		NotificationCenter.default.addObserver(self, selector: #selector(syncProgressDidChange(_:)), name: .progressInfoDidChange, object: syncProgress)
		Self.logger.debug("CloutKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		await withCheckedContinuation { continuation in
			let op = CloudKitRemoteNotificationOperation(accountZone: accountZone, articlesZone: articlesZone, userInfo: userInfo)
			op.completionBlock = { _ in
				Self.logger.debug("CloutKitAccountDelegate: \(#function, privacy: .public) did complete")
				continuation.resume()
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func refreshAll(for account: Account) async throws {
		guard refreshProgressInfo.isComplete else {
			return
		}

		syncProgress.reset()

		guard NetworkMonitor.shared.isConnected else {
			return
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		try await standardRefreshAll(for: account)
		Self.logger.debug("CloutKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func syncArticleStatus(for account: Account) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func sendArticleStatus(for account: Account) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		try await sendArticleStatus(account: account, showProgress: false)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func refreshArticleStatus(for account: Account) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let op = CloudKitReceiveStatusOperation(articlesZone: articlesZone)
			op.completionBlock = { mainThreadOperation in
				Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
				if mainThreadOperation.isCanceled {
					continuation.resume(throwing: CloudKitAccountDelegateError.unknown)
				} else {
					continuation.resume(returning: ())
				}
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func importOPML(for account: Account, opmlFile: URL) async throws {
		guard refreshProgressInfo.isComplete else {
			return
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		let opmlData = try Data(contentsOf: opmlFile)
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		let opmlDocument = try RSOPMLParser.parseOPML(with: parserData)

		// TODO: throw appropriate error if OPML file is empty.
		guard let opmlItems = opmlDocument.children, let rootExternalID = account.externalID else {
			return
		}
		let normalizedItems = OPMLNormalizer.normalize(opmlItems)

		syncProgress.addTask()
		defer {
			syncProgress.completeTask()
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}

		do {
			try await accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
			try? await standardRefreshAll(for: account)
		} catch {
			throw error
		}
	}

	@discardableResult
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) url: \(urlString)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete url: \(urlString)")
		}
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		let editedName = name == nil || name!.isEmpty ? nil : name
		return try await createRSSFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed)
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		let editedName = name.isEmpty ? nil : name
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
			syncProgress.completeTask()
		}

		do {
			try await accountZone.renameFeed(feed, editedName: editedName)
			feed.editedName = name
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
		}

		do {
			try await removeFeedFromCloud(for: account, with: feed, from: container)
			account.clearFeedMetadata(feed)
			container.removeFeedFromTreeAtTopLevel(feed)
		} catch {
			switch error {
			case CloudKitZoneError.corruptAccount:
				// We got into a bad state and should remove the feed to clear up the bad data
				account.clearFeedMetadata(feed)
				container.removeFeedFromTreeAtTopLevel(feed)
			default:
				throw error
			}
		}
	}

	func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
			syncProgress.completeTask()
		}

		do {
			try await accountZone.moveFeed(feed, from: sourceContainer, to: destinationContainer)
			sourceContainer.removeFeedFromTreeAtTopLevel(feed)
			destinationContainer.addFeedToTreeAtTopLevel(feed)
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func addFeed(account: Account, feed: Feed, container: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
			syncProgress.completeTask()
		}

		do {
			try await accountZone.addFeed(feed, to: container)
			container.addFeedToTreeAtTopLevel(feed)
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feed.url: \(feed.url)")
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) name: \(name)")
		syncProgress.addTask()
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete name: \(name)")
			syncProgress.completeTask()
		}

		do {
			let externalID = try await accountZone.createFolder(name: name)
			guard let folder = account.ensureFolder(with: name) else {
				throw AccountError.invalidParameter
			}
			folder.externalID = externalID
			return folder
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) new name: \(name)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete new name: \(name)")
		}
		syncProgress.addTask()
		defer { syncProgress.completeTask() }

		do {
			try await accountZone.renameFolder(folder, to: name)
			folder.name = name
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) name: \(folder.name ?? "")")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete name: \(folder.name ?? "")")
		}
		syncProgress.addTask()

		let feedExternalIDs: [String]
		do {
			feedExternalIDs = try await accountZone.findFeedExternalIDs(for: folder)
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			syncProgress.completeTask()
			processAccountError(account, error)
			throw error
		}

		let feeds = feedExternalIDs.compactMap { account.existingFeed(withExternalID: $0) }
		var errorOccurred = false

		await withTaskGroup(of: Result<Void, Error>.self) { group in
			for feed in feeds {
				group.addTask {
					do {
						try await self.removeFeedFromCloud(for: account, with: feed, from: folder)
						return .success(())
					} catch {
						Self.logger.error("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
						return .failure(error)
					}
				}
			}

			for await result in group {
				if case .failure = result {
					errorOccurred = true
				}
			}
		}

		guard !errorOccurred else {
			syncProgress.completeTask()
			throw CloudKitAccountDelegateError.unknown
		}

		do {
			try await accountZone.removeFolder(folder)
			syncProgress.completeTask()
			account.removeFolderFromTree(folder)
		} catch {
			syncProgress.completeTask()
			throw error
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {
		guard let name = folder.name else {
			throw AccountError.invalidParameter
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) name: \(name)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete name: \(name)")
		}

		let feedsToRestore = folder.topLevelFeeds
		syncProgress.addTasks(1 + feedsToRestore.count)

		do {
			let externalID = try await accountZone.createFolder(name: name)
			syncProgress.completeTask()

			folder.externalID = externalID
			account.addFolderToTree(folder)

			await withTaskGroup(of: Void.self) { group in
				for feed in feedsToRestore {
					folder.topLevelFeeds.remove(feed)

					group.addTask {
						do {
							try await self.restoreFeed(for: account, feed: feed, container: folder)
							await self.syncProgress.completeTask()
						} catch {
							Self.logger.error("CloudKit: Restore folder feed error: \(error.localizedDescription)")
							await self.syncProgress.completeTask()
						}
					}
				}
			}

			account.addFolderToTree(folder)
		} catch {
			syncProgress.completeTask()
			processAccountError(account, error)
			throw error
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		let articles = try await account.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account)
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func accountDidInitialize(_ account: Account) {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		self.account = account

		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, articlesZone: articlesZone)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account, database: syncDatabase, articlesZone: articlesZone)

		syncDatabase.resetAllSelectedForProcessing()

		// Check to see if this is a new account and initialize anything we need
		if account.externalID == nil {
			Task {
				do {
					let externalID = try await accountZone.findOrCreateAccount()
					account.externalID = externalID
					try? await self.initialRefreshAll(for: account)
				} catch {
					Self.logger.error("CloudKitAccountDelegate: \(#function, privacy: .public) error: \(error.localizedDescription)")
				}
			}
			accountZone.subscribeToZoneChanges()
			articlesZone.subscribeToZoneChanges()
		}

	}

	func accountWillBeDeleted(_ account: Account) {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		accountZone.resetChangeToken()
		articlesZone.resetChangeToken()
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		nil
	}

	// MARK: - Suspend and Resume (for iOS)

	func suspendNetwork() {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		refresher.suspend()
	}

	func suspendDatabase() {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		syncDatabase.suspend()
	}

	func resume() {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		refresher.resume()
		syncDatabase.resume()
	}
}

// MARK: - Refresh Progress

private extension CloudKitAccountDelegate {

	func updateProgress() {
		progressInfo = ProgressInfo.combined([refreshProgressInfo, syncProgressInfo])
	}

	@objc func refreshProgressDidChange(_ note: Notification) {
		refreshProgressInfo = refresher.progressInfo
	}

	@objc func syncProgressDidChange(_ note: Notification) {
		syncProgressInfo = syncProgress.progressInfo
	}
}

// MARK: - Private

private extension CloudKitAccountDelegate {

	func initialRefreshAll(for account: Account) async throws {
		try await performRefreshAll(for: account, sendArticleStatus: false)
	}

	func standardRefreshAll(for account: Account) async throws {
		try await performRefreshAll(for: account, sendArticleStatus: true)
	}

	func performRefreshAll(for account: Account, sendArticleStatus: Bool) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) sendArticleStatus: \(sendArticleStatus ? "true" : "false")")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}

		syncProgress.addTasks(3)

		do {
			try await accountZone.fetchChangesInZone()
			syncProgress.completeTask()

			let feeds = account.flattenedFeeds()

			try await refreshArticleStatus(for: account)
			syncProgress.completeTask()

			await refresher.refreshFeeds(feeds)

			if sendArticleStatus {
				try await self.sendArticleStatus(account: account, showProgress: true)
			}

			syncProgress.reset()
			account.metadata.lastArticleFetchEndTime = Date()
		} catch {
			processAccountError(account, error)
			syncProgress.reset()
			throw error
		}
	}

	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) url: \(url)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete url: \(url)")
		}
		syncProgress.addTasks(5)

		do {
			let feedSpecifiers = try await FeedFinder.find(url: url)
			syncProgress.completeTask()

			guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
				  let feedURL = URL(string: bestFeedSpecifier.urlString) else {
				syncProgress.completeTasks(3)
				if validateFeed {
					syncProgress.completeTask()
					throw AccountError.createErrorNotFound
				} else {
					return try await addDeadFeed(account: account, url: url, editedName: editedName, container: container)
				}
			}

			if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
				syncProgress.completeTasks(4)
				throw AccountError.createErrorAlreadySubscribed
			}

			return try await createAndSyncFeed(account: account,
											   feedURL: feedURL,
											   bestFeedSpecifier: bestFeedSpecifier,
											   editedName: editedName,
											   container: container)
		} catch {
			syncProgress.completeTasks(3)
			if validateFeed {
				syncProgress.completeTask()
				throw AccountError.createErrorNotFound
			} else {
				return try await addDeadFeed(account: account, url: url, editedName: editedName, container: container)
			}
		}
	}

	func createAndSyncFeed(account: Account, feedURL: URL, bestFeedSpecifier: FeedSpecifier, editedName: String?, container: Container) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feedURL: \(feedURL)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete feedURL: \(feedURL)")
		}
		let feed = account.createFeed(with: nil, url: feedURL.absoluteString, feedID: feedURL.absoluteString, homePageURL: nil)
		feed.editedName = editedName
		container.addFeedToTreeAtTopLevel(feed)

		do {
			let parsedFeed = try await downloadAndParseFeed(feedURL: feedURL, feed: feed)
			try await updateAndCreateFeedInCloud(account: account,
												 feed: feed,
												 parsedFeed: parsedFeed,
												 bestFeedSpecifier: bestFeedSpecifier,
												 editedName: editedName,
												 container: container)
			return feed
		} catch {
			container.removeFeedFromTreeAtTopLevel(feed)
			syncProgress.completeTasks(3)
			throw error
		}
	}

	func downloadAndParseFeed(feedURL: URL, feed: Feed) async throws -> ParsedFeed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feedURL: \(feedURL)")
		let (parsedFeed, response) = try await InitialFeedDownloader.download(feedURL)
		syncProgress.completeTask()
		feed.lastCheckDate = Date()

		guard let parsedFeed else {
			throw AccountError.createErrorNotFound
		}

		// Save conditional GET info so that first refresh uses conditional GET.
		if let httpResponse = response as? HTTPURLResponse,
		   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
			feed.conditionalGetInfo = conditionalGetInfo
		}

		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		return parsedFeed
	}

	func updateAndCreateFeedInCloud(account: Account, feed: Feed, parsedFeed: ParsedFeed, bestFeedSpecifier: FeedSpecifier, editedName: String?, container: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) feed.url: \(feed.url)")
		_ = try await account.updateAsync(feed: feed, parsedFeed: parsedFeed)

		let externalID = try await accountZone.createFeed(url: bestFeedSpecifier.urlString,
														  name: parsedFeed.title,
														  editedName: editedName,
														  homePageURL: parsedFeed.homePageURL,
														  container: container)
		syncProgress.completeTask()
		feed.externalID = externalID
		sendNewArticlesToTheCloud(account, feed)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func addDeadFeed(account: Account, url: URL, editedName: String?, container: Container) async throws -> Feed {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		let feed = account.createFeed(with: editedName, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		container.addFeedToTreeAtTopLevel(feed)

		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
			syncProgress.completeTask()
		}

		do {
			let externalID = try await accountZone.createFeed(url: url.absoluteString,
															  name: editedName,
															  editedName: nil,
															  homePageURL: nil,
															  container: container)
			feed.externalID = externalID
			return feed
		} catch {
			container.removeFeedFromTreeAtTopLevel(feed)
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) error: \(error.localizedDescription)")
			throw error
		}
	}

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: Feed) {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		Task {
			do {
				let articles = try await account.fetchArticlesAsync(.feed(feed))

				await storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>())
				syncProgress.completeTask()

				try await sendArticleStatus(account: account, showProgress: true)
				try? await articlesZone.fetchChangesInZone()
			} catch {
				Self.logger.error("CloudKitAccountDelegate: \(#function, privacy: .public) error: \(error.localizedDescription)")
			}
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}
	}

	func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) \(error)")
			account.removeFeedsFromTreeAtTopLevel(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolderFromTree(folder)
			}
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}
	}

	func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) async {
		// New records with a read status aren't really new, they just didn't have the read article stored
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		await withTaskGroup(of: Void.self) { group in
			if let new = new {
				let filteredNew = new.filter { $0.status.read == false }
				group.addTask {
					await self.insertSyncStatuses(articles: filteredNew, statusKey: .new, flag: true)
				}
			}

			group.addTask {
				await self.insertSyncStatuses(articles: updated, statusKey: .new, flag: false)
			}

			group.addTask {
				await self.insertSyncStatuses(articles: deleted, statusKey: .deleted, flag: true)
			}
		}
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool) async {
		guard let articles = articles, !articles.isEmpty else {
			return
		}
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		})
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		try? await syncDatabase.insertStatuses(syncStatuses)
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
	}

	func sendArticleStatus(account: Account, showProgress: Bool) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let op = CloudKitSendStatusOperation(account: account,
												 articlesZone: articlesZone,
												 database: syncDatabase)
			op.completionBlock = { mainThreadOperation in
				Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
				if mainThreadOperation.isCanceled {
					continuation.resume(throwing: CloudKitAccountDelegateError.unknown)
				} else {
					continuation.resume(returning: ())
				}
			}
			mainThreadOperationQueue.add(op)
		}
	}

	func removeFeedFromCloud(for account: Account, with feed: Feed, from container: Container) async throws {
		Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public)")
		defer {
			Self.logger.debug("CloudKitAccountDelegate: \(#function, privacy: .public) did complete")
		}

		syncProgress.addTasks(2)

		do {
			_ = try await accountZone.removeFeed(feed, from: container)
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			syncProgress.completeTask()
			processAccountError(account, error)
			throw error
		}

		guard let feedExternalID = feed.externalID else {
			syncProgress.completeTask()
			return
		}

		do {
			try await articlesZone.deleteArticles(feedExternalID)
			feed.dropConditionalGetInfo()
			syncProgress.completeTask()
		} catch {
			syncProgress.completeTask()
			processAccountError(account, error)
			throw error
		}
	}
}

extension CloudKitAccountDelegate: LocalAccountRefresherDelegate {

	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
		Task {
			await storeArticleChanges(new: articleChanges.new,
									  updated: articleChanges.updated,
									  deleted: articleChanges.deleted)
		}
	}
}
