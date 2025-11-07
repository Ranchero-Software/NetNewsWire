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
import SyncDatabase
import RSCore
import RSParser
import Articles
import ArticlesDatabase
import RSWeb
import Secrets
import CloudKitSync

enum CloudKitAccountDelegateError: LocalizedError {
	case invalidParameter
	case unknown

	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

final class CloudKitAccountDelegate: AccountDelegate {
	private static let logger = cloudKitLogger

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

	/// refreshProgress is combined sync progress and feed download progress.
	let refreshProgress = DownloadProgress(numberOfTasks: 0)
	private let syncProgress = DownloadProgress(numberOfTasks: 0)

	init(dataFolder: String) {

		self.accountZone = CloudKitAccountZone(container: container)
		self.articlesZone = CloudKitArticlesZone(container: container)

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		self.syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		self.refresher = LocalAccountRefresher()
		self.refresher.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: refresher.downloadProgress)
		NotificationCenter.default.addObserver(self, selector: #selector(syncProgressDidChange(_:)), name: .DownloadProgressDidChange, object: syncProgress)
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
		await withCheckedContinuation { continuation in
			receiveRemoteNotification(for: account, userInfo: userInfo) {
				continuation.resume()
			}
		}
	}

	private func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		let op = CloudKitRemoteNotificationOperation(accountZone: accountZone, articlesZone: articlesZone, userInfo: userInfo)
		op.completionBlock = { mainThreadOperaion in
			completion()
		}
		mainThreadOperationQueue.add(op)
	}

	func refreshAll(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshAll(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {

		guard refreshProgress.isComplete else {
			completion(.success(()))
			return
		}

		syncProgress.reset()

		guard NetworkMonitor.shared.isConnected else {
			completion(.success(()))
			return
		}

		standardRefreshAll(for: account, completion: completion)
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		sendArticleStatus(for: account, showProgress: false, completion: completion)
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let op = CloudKitReceiveStatusOperation(articlesZone: articlesZone)
		op.completionBlock = { mainThreadOperaion in
			if mainThreadOperaion.isCanceled {
				completion(.failure(CloudKitAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}
		mainThreadOperationQueue.add(op)
	}

	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
		guard refreshProgress.isComplete else {
			return
		}

		let opmlData = try Data(contentsOf: opmlFile)
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		let opmlDocument = try RSOPMLParser.parseOPML(with: parserData)

		// TODO: throw appropriate error if OPML file is empty.
		guard let opmlItems = opmlDocument.children, let rootExternalID = account.externalID else {
			return
		}
		let normalizedItems = OPMLNormalizer.normalize(opmlItems)

		syncProgress.addToNumberOfTasksAndRemaining(1)

		do {
			try await accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
			self.syncProgress.completeTask()
			try? await standardRefreshAll(for: account)
		} catch {
			self.syncProgress.completeTask()
			throw error
		}
	}

	@discardableResult
	@MainActor func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		let editedName = name == nil || name!.isEmpty ? nil : name

		return try await withCheckedThrowingContinuation { continuation in
			self.createRSSFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFeed(for: account, with: feed, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let editedName = name.isEmpty ? nil : name
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.renameFeed(feed, editedName: editedName) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				feed.editedName = name
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	@MainActor func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			removeFeed(for: account, with: feed, from: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		removeFeedFromCloud(for: account, with: feed, from: container) { result in
			switch result {
			case .success:
				account.clearFeedMetadata(feed)
				container.removeFeedFromTreeAtTopLevel(feed)
				completion(.success(()))
			case .failure(let error):
				switch error {
				case CloudKitZoneError.corruptAccount:
					// We got into a bad state and should remove the feed to clear up the bad data
					account.clearFeedMetadata(feed)
					container.removeFeedFromTreeAtTopLevel(feed)
				default:
					completion(.failure(error))
				}
			}
		}
	}

	@MainActor func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {
		try await withCheckedThrowingContinuation{ continuation in
			moveFeed(for: account, with: feed, from: from, to: to) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func moveFeed(for account: Account, with feed: Feed, from fromContainer: Container, to toContainer: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.moveFeed(feed, from: fromContainer, to: toContainer) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				fromContainer.removeFeedFromTreeAtTopLevel(feed)
				toContainer.addFeedToTreeAtTopLevel(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	@MainActor func addFeed(account: Account, feed: Feed, container: Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			addFeed(for: account, with: feed, to: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.addFeed(feed, to: container) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				container.addFeedToTreeAtTopLevel(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
	}

	private func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		try await withCheckedThrowingContinuation { continuation in
			createFolder(for: account, name: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.createFolder(name: name) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success(let externalID):
				if let folder = account.ensureFolder(with: name) {
					folder.externalID = externalID
					completion(.success(folder))
				} else {
					completion(.failure(AccountError.invalidParameter))
				}
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFolder(for: account, with: folder, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.renameFolder(folder, to: name) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				folder.name = name
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	@MainActor func removeFolder(for account: Account, with folder: Folder) async throws {
		try await withCheckedThrowingContinuation { continuation in
			removeFolder(for: account, with: folder) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {

		syncProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.findFeedExternalIDs(for: folder) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success(let feedExternalIDs):

				let feeds = feedExternalIDs.compactMap { account.existingFeed(withExternalID: $0) }
				let group = DispatchGroup()
				var errorOccurred = false

				for feed in feeds {
					group.enter()
					self.removeFeedFromCloud(for: account, with: feed, from: folder) { result in
						group.leave()
						if case .failure(let error) = result {
							Self.logger.error("CloudKit: Remove folder, remove feed error: \(error.localizedDescription)")
							errorOccurred = true
						}
					}
				}

				group.notify(queue: DispatchQueue.global(qos: .background)) {
					DispatchQueue.main.async {
						guard !errorOccurred else {
							self.syncProgress.completeTask()
							completion(.failure(CloudKitAccountDelegateError.unknown))
							return
						}

						self.accountZone.removeFolder(folder) { result in
							self.syncProgress.completeTask()
							switch result {
							case .success:
								account.removeFolderFromTree(folder)
								completion(.success(()))
							case .failure(let error):
								completion(.failure(error))
							}
						}
					}
				}

			case .failure(let error):
				self.syncProgress.completeTask()
				self.syncProgress.completeTask()
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}

	}

	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws {
		try await withCheckedThrowingContinuation { continuation in
			restoreFolder(for: account, folder: folder) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let name = folder.name else {
			completion(.failure(AccountError.invalidParameter))
			return
		}

		let feedsToRestore = folder.topLevelFeeds
		syncProgress.addToNumberOfTasksAndRemaining(1 + feedsToRestore.count)

		accountZone.createFolder(name: name) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success(let externalID):
				folder.externalID = externalID
				account.addFolder(folder)

				let group = DispatchGroup()
				for feed in feedsToRestore {

					folder.topLevelFeeds.remove(feed)

					group.enter()
					self.restoreFeed(for: account, feed: feed, container: folder) { result in
						self.syncProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							break
						case .failure(let error):
							Self.logger.error("CloudKit: Restore folder feed error: \(error.localizedDescription)")
						}
					}

				}

				group.notify(queue: DispatchQueue.main) {
					account.addFolder(folder)
					completion(.success(()))
				}

			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		let articles = try await account.update(articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})
		
		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account

		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, articlesZone: articlesZone)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account, database: syncDatabase, articlesZone: articlesZone)

		syncDatabase.resetAllSelectedForProcessing()

		// Check to see if this is a new account and initialize anything we need
		if account.externalID == nil {
			accountZone.findOrCreateAccount() { result in
				switch result {
				case .success(let externalID):
					account.externalID = externalID
					self.initialRefreshAll(for: account) { _ in }
				case .failure(let error):
					Self.logger.error("CloudKit: Error adding account container: \(error.localizedDescription)")
				}
			}
			accountZone.subscribeToZoneChanges()
			articlesZone.subscribeToZoneChanges()
		}

	}

	func accountWillBeDeleted(_ account: Account) {
		accountZone.resetChangeToken()
		articlesZone.resetChangeToken()
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		nil
	}

	// MARK: - Suspend and Resume (for iOS)

	func suspendNetwork() {
		refresher.suspend()
	}

	func suspendDatabase() {
		syncDatabase.suspend()
	}

	func resume() {
		refresher.resume()
		syncDatabase.resume()
	}
}

// MARK: - Refresh Progress

private extension CloudKitAccountDelegate {

	func updateRefreshProgress() {

		refreshProgress.numberOfTasks = refresher.downloadProgress.numberOfTasks + syncProgress.numberOfTasks
		refreshProgress.numberRemaining = refresher.downloadProgress.numberRemaining + syncProgress.numberRemaining

		// Complete?
		if refreshProgress.numberOfTasks > 0 && refreshProgress.numberRemaining < 1 {
			refresher.downloadProgress.numberOfTasks = 0
			syncProgress.numberOfTasks = 0
		}
	}

	@objc func downloadProgressDidChange(_ note: Notification) {

		updateRefreshProgress()
	}

	@objc func syncProgressDidChange(_ note: Notification) {

		updateRefreshProgress()
	}
}

// MARK: - Private

private extension CloudKitAccountDelegate {

	func initialRefreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {

		func fail(_ error: Error) {
			self.processAccountError(account, error)
			self.syncProgress.reset()
			completion(.failure(error))
		}

		syncProgress.addToNumberOfTasksAndRemaining(3)
		accountZone.fetchChangesInZone() { result in
			self.syncProgress.completeTask()

			let feeds = account.flattenedFeeds()

			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					self.syncProgress.completeTask()
					switch result {
					case .success:

						self.combinedRefresh(account, feeds) {
							self.syncProgress.reset()
							account.metadata.lastArticleFetchEndTime = Date()
						}

					case .failure(let error):
						fail(error)
					}
				}
			case .failure(let error):
				fail(error)
			}
		}
	}

	@MainActor func standardRefreshAll(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			standardRefreshAll(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func standardRefreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {

		syncProgress.addToNumberOfTasksAndRemaining(3)

		func fail(_ error: Error) {
			self.processAccountError(account, error)
			self.syncProgress.reset()
			completion(.failure(error))
		}

		accountZone.fetchChangesInZone() { result in
			switch result {
			case .success:

				self.syncProgress.completeTask()
				let feeds = account.flattenedFeeds()

				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						self.syncProgress.completeTask()
						self.combinedRefresh(account, feeds) {
							self.sendArticleStatus(for: account, showProgress: true) { _ in
								self.syncProgress.reset()
								account.metadata.lastArticleFetchEndTime = Date()
								completion(.success(()))
							}
						}
					case .failure(let error):
						fail(error)
					}
				}

			case .failure(let error):
				fail(error)
			}
		}
	}

	func combinedRefresh(_ account: Account, _ feeds: Set<Feed>, completion: @escaping () -> Void) {
		Task { @MainActor in
			await refresher.refreshFeeds(feeds)
			completion()
		}
	}

	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {

		func addDeadFeed() {
			let feed = account.createFeed(with: editedName, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
			container.addFeedToTreeAtTopLevel(feed)

			self.accountZone.createFeed(url: url.absoluteString,
										   name: editedName,
										   editedName: nil,
										   homePageURL: nil,
										   container: container) { result in

				self.syncProgress.completeTask()
				switch result {
				case .success(let externalID):
					feed.externalID = externalID
					completion(.success(feed))
				case .failure(let error):
					container.removeFeedFromTreeAtTopLevel(feed)
					completion(.failure(error))
				}
			}
		}

		syncProgress.addToNumberOfTasksAndRemaining(5)
		FeedFinder.find(url: url) { result in

			self.syncProgress.completeTask()
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers), let url = URL(string: bestFeedSpecifier.urlString) else {
					self.syncProgress.completeTasks(3)
					if validateFeed {
						self.syncProgress.completeTask()
						completion(.failure(AccountError.createErrorNotFound))
					} else {
						addDeadFeed()
					}
					return
				}

				if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
					self.syncProgress.completeTasks(4)
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}

				let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
				feed.editedName = editedName
				container.addFeedToTreeAtTopLevel(feed)

				InitialFeedDownloader.download(url) { parsedFeed, _, response, _ in
					self.syncProgress.completeTask()
					feed.lastCheckDate = Date()

					if let parsedFeed {
						// Save conditional GET info so that first refresh uses conditional GET.
						if let httpResponse = response as? HTTPURLResponse,
						   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
							feed.conditionalGetInfo = conditionalGetInfo
						}

						account.update(feed, with: parsedFeed) { result in
							switch result {
							case .success:

								self.accountZone.createFeed(url: bestFeedSpecifier.urlString,
															   name: parsedFeed.title,
															   editedName: editedName,
															   homePageURL: parsedFeed.homePageURL,
															   container: container) { result in

									self.syncProgress.completeTask()
									switch result {
									case .success(let externalID):
										feed.externalID = externalID
										self.sendNewArticlesToTheCloud(account, feed)
										completion(.success(feed))
									case .failure(let error):
										container.removeFeedFromTreeAtTopLevel(feed)
										self.syncProgress.completeTasks(2)
										completion(.failure(error))
									}
								}

							case .failure(let error):
								container.removeFeedFromTreeAtTopLevel(feed)
								self.syncProgress.completeTasks(3)
								completion(.failure(error))
							}

						}
					} else {
						self.syncProgress.completeTasks(3)
						container.removeFeedFromTreeAtTopLevel(feed)
						completion(.failure(AccountError.createErrorNotFound))
					}

				}

			case .failure:
				self.syncProgress.completeTasks(3)
				if validateFeed {
					self.syncProgress.completeTask()
					completion(.failure(AccountError.createErrorNotFound))
					return
				} else {
					addDeadFeed()
				}
			}
		}
	}

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: Feed) {
		account.fetchArticlesAsync(.feed(feed)) { result in
			switch result {
			case .success(let articles):
				self.storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>()) {
					self.syncProgress.completeTask()
					self.sendArticleStatus(for: account, showProgress: true) { result in
						switch result {
						case .success:
							self.articlesZone.fetchChangesInZone() { _ in }
						case .failure(let error):
							Self.logger.error("CloudKit: Feed send articles error: \(error.localizedDescription)")
						}
					}
				}
			case .failure(let error):
				Self.logger.error("CloudKit: Feed send articles error: \(error.localizedDescription)")
			}
		}
	}

	func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeedsFromTreeAtTopLevel(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolderFromTree(folder)
			}
		}
	}

	func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?, completion: (() -> Void)?) {
		// New records with a read status aren't really new, they just didn't have the read article stored
		let group = DispatchGroup()
		if let new = new {
			let filteredNew = new.filter { $0.status.read == false }
			group.enter()
			insertSyncStatuses(articles: filteredNew, statusKey: .new, flag: true) {
				group.leave()
			}
		}

		group.enter()
		insertSyncStatuses(articles: updated, statusKey: .new, flag: false) {
			group.leave()
		}

		group.enter()
		insertSyncStatuses(articles: deleted, statusKey: .deleted, flag: true) {
			group.leave()
		}

		group.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
			DispatchQueue.main.async {
				completion?()
			}
		}
	}

	func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool, completion: @escaping () -> Void) {
		guard let articles = articles, !articles.isEmpty else {
			completion()
			return
		}
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		})
		Task { @MainActor in
			try? await syncDatabase.insertStatuses(syncStatuses)
			completion()
		}
	}

	func sendArticleStatus(for account: Account, showProgress: Bool, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let op = CloudKitSendStatusOperation(account: account,
											 articlesZone: articlesZone,
											 refreshProgress: refreshProgress,
											 showProgress: showProgress,
											 database: syncDatabase)
		op.completionBlock = { mainThreadOperation in
			if mainThreadOperation.isCanceled {
				completion(.failure(CloudKitAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}
		mainThreadOperationQueue.add(op)
	}


	func removeFeedFromCloud(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.removeFeed(feed, from: container) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				guard let feedExternalID = feed.externalID else {
					completion(.success(()))
					return
				}
				self.articlesZone.deleteArticles(feedExternalID) { result in
					feed.dropConditionalGetInfo()
					self.syncProgress.completeTask()
					completion(result)
				}
			case .failure(let error):
				self.syncProgress.completeTask()
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

}

extension CloudKitAccountDelegate: LocalAccountRefresherDelegate {

	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
		self.storeArticleChanges(new: articleChanges.newArticles,
								 updated: articleChanges.updatedArticles,
								 deleted: articleChanges.deletedArticles,
								 completion: nil)
	}
}
