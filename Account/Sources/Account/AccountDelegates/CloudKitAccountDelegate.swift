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
import Parser
import ParserObjC
import Articles
import ArticlesDatabase
import Web
import Secrets
import Core
import CommonErrors
import FeedFinder
import LocalAccount
import CloudKitSync

enum CloudKitAccountDelegateError: LocalizedError {
	case invalidParameter
	case unknown
	
	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

@MainActor final class CloudKitAccountDelegate: AccountDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	private let database: SyncDatabase
	
	private let container: CKContainer = {
		let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as! String
		return CKContainer(identifier: "iCloud.\(orgID).NetNewsWire")
	}()
	
	private let accountZone: CloudKitAccountZone
	private let articlesZone: CloudKitArticlesZone
	
	private let mainThreadOperationQueue = MainThreadOperationQueue()

//	private lazy var refresher: LocalAccountRefresher = {
//		let refresher = LocalAccountRefresher()
//		refresher.delegate = self
//		return refresher
//	}()

	weak var account: Account?
	
	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false
	
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	init(dataFolder: String) {
		accountZone = CloudKitAccountZone(container: container)
		articlesZone = CloudKitArticlesZone(container: container)
		
		let databasePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		database = SyncDatabase(databasePath: databasePath)
	}
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {

		await withCheckedContinuation { continuation in
			self.receiveRemoteNotification(for: account, userInfo: userInfo) {
				continuation.resume()
			}
		}
	}

	private func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		let op = CloudKitRemoteNotificationOperation(accountZone: accountZone, articlesZone: articlesZone, userInfo: userInfo)
		op.completionBlock = { mainThreadOperaion in
			completion()
		}
		Task {
			mainThreadOperationQueue.add(op)
		}
	}
	
	func refreshAll(for account: Account) async throws {
		
		guard refreshProgress.isComplete, Reachability.internetIsReachable else {
			return
		}
		try await standardRefreshAll(for: account)
	}

	func syncArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				switch result {
				case .success:
					self.refreshArticleStatus(for: account) { result in
						switch result {
						case .success:
							continuation.resume()
						case .failure(let error):
							continuation.resume(throwing: error)
						}
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func sendArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.sendArticleStatus(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		sendArticleStatus(for: account, showProgress: false, completion: completion)
	}
	
	func refreshArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.refreshArticleStatus(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let op = CloudKitReceiveStatusOperation(articlesZone: articlesZone)
		op.completionBlock = { mainThreadOperation in
			Task { @MainActor in
				if mainThreadOperation.isCanceled {
					completion(.failure(CloudKitAccountDelegateError.unknown))
				} else {
					completion(.success(()))
				}
			}
		}
		Task { @MainActor in
			mainThreadOperationQueue.add(op)
		}
	}
	
	func importOPML(for account: Account, opmlFile: URL) async throws {

		guard refreshProgress.isComplete else {
			return
		}

		let opmlData = try Data(contentsOf: opmlFile)
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		let opmlDocument = try RSOPMLParser.parseOPML(with: parserData)

		guard let opmlItems = opmlDocument.children, let rootExternalID = account.externalID else {
			return
		}

		let normalizedItems = OPMLNormalizer.normalize(opmlItems)
		
		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		try await accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems)
		try await standardRefreshAll(for: account)
	}
	
	@discardableResult
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		guard let url = URL(string: urlString) else {
			throw LocalAccountDelegateError.invalidParameter
		}
		
		let editedName = name == nil || name!.isEmpty ? nil : name

		return try await createRSSFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed)
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		guard let feedExternalID = feed.externalID else {
			throw LocalAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		let editedName = name.isEmpty ? nil : name
		
		do {
			try await accountZone.renameFeed(externalID: feedExternalID, editedName: editedName)
			feed.editedName = name
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func removeFeed(for account: Account, with feed: Feed, from container: Container) async throws {

		do {
			try await removeFeedFromCloud(for: account, with: feed, from: container)
			account.clearFeedMetadata(feed)
			container.removeFeed(feed)

		} catch {

			switch error {
			case CloudKitZoneError.corruptAccount:
				// We got into a bad state and should remove the feed to clear up the bad data
				account.clearFeedMetadata(feed)
				container.removeFeed(feed)
			default:
				throw error
			}
		}
	}
	
	func moveFeed(for account: Account, with feed: Feed, from sourceContainer: Container, to destinationContainer: Container) async throws {

		guard let feedExternalID = feed.externalID, let sourceContainerExternalID = sourceContainer.externalID, let destinationContainerExternalID = destinationContainer.externalID else {
			throw LocalAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await accountZone.moveFeed(externalID: feedExternalID, from: sourceContainerExternalID, to: destinationContainerExternalID)
			sourceContainer.removeFeed(feed)
			destinationContainer.addFeed(feed)
		} catch {
			processAccountError(account, error)
			throw error
		}
	}
	
	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		guard let feedExternalID = feed.externalID, let containerExternalID = container.externalID else {
			throw LocalAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await accountZone.addFeed(externalID: feedExternalID, to: containerExternalID)
			container.addFeed(feed)
		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		try await createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true)
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		var externalID: String!

		do {
			externalID = try await accountZone.createFolder(name: name)
		} catch {
			processAccountError(account, error)
			throw error
		}

		if let folder = account.ensureFolder(with: name) {
			folder.externalID = externalID
			return folder
		} else {
			throw CloudKitAccountDelegateError.invalidParameter
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		guard let folderExternalID = folder.externalID else {
			throw CloudKitAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await accountZone.renameFolder(externalID: folderExternalID, to: name)
			folder.name = name
		} catch {
			processAccountError(account, error)
			throw error
		}
	}
	
	func removeFolder(for account: Account, with folder: Folder) async throws {

		guard let folderExternalID = folder.externalID else {
			throw CloudKitAccountDelegateError.invalidParameter
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			let feedExternalIDs = try await accountZone.findFeedExternalIDs(for: folderExternalID)

			let feeds = feedExternalIDs.compactMap { account.existingFeed(withExternalID: $0) }
			var errorOccurred = false
			refreshProgress.addTasks(feeds.count)

			for feed in feeds {
				do {
					try await removeFeedFromCloud(for: account, with: feed, from: folder)
				} catch {
					os_log(.error, log: self.log, "Remove folder, remove feed error: %@.", error.localizedDescription)
					errorOccurred = true
				}
				refreshProgress.completeTask()
			}

			if errorOccurred {
				throw CloudKitAccountDelegateError.unknown
			}

			try await accountZone.removeFolder(externalID: folderExternalID)
			account.removeFolder(folder: folder)

		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func restoreFolder(for account: Account, folder: Folder) async throws {

		guard let name = folder.name else {
			throw CloudKitAccountDelegateError.invalidParameter
		}

		let feedsToRestore = folder.topLevelFeeds
		refreshProgress.addTasks(1 + feedsToRestore.count)

		do {
			let externalID = try await accountZone.createFolder(name: name)

			folder.externalID = externalID
			account.addFolder(folder)

			for feed in feedsToRestore {

				folder.topLevelFeeds.remove(feed)

				do {
					try await self.restoreFeed(for: account, feed: feed, container: folder)
				} catch {
					os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
				}

				refreshProgress.completeTask()
			}

			account.addFolder(folder)
			refreshProgress.completeTask()

		} catch {
			processAccountError(account, error)
			throw error
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		let articles = try await account.update(articles: articles, statusKey: statusKey, flag: flag)

		let syncStatuses = articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		}

		try? await database.insertStatuses(Set(syncStatuses))
		if let count = try? await self.database.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account, showProgress: false)
		}
	}

	private func articleSupport() -> CloudKitArticlesZoneDelegate.ArticleSupport {

		CloudKitArticlesZoneDelegate.ArticleSupport(
			delete: { [weak self] articleIDs in
				Task { @MainActor in
					try? await self?.account?.delete(articleIDs: articleIDs)
				}
			},
			markRead: { [weak self] articleIDs in
				Task { @MainActor in
					try? await self?.account?.markAsRead(articleIDs)
				}
			},
			markUnread: { [weak self] articleIDs in
				Task { @MainActor in
					try? await self?.account?.markAsUnread(articleIDs)
				}
			},
			markStarred: { [weak self] articleIDs in
				Task { @MainActor in
					try? await self?.account?.markAsStarred(articleIDs)
				}
			},
			markUnstarred: { [weak self] articleIDs in
				Task { @MainActor in
					try? await self?.account?.markAsUnstarred(articleIDs)
				}
			},
			update: { [weak self] (feedID, parsedItems, deleteOlder) async throws -> ArticleChanges? in
				try await self?.account?.update(feedID: feedID, with: parsedItems, deleteOlder: deleteOlder)
			}
		)
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
		
		accountZone.delegate = CloudKitAcountZoneDelegate(account: account)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(articleSupport: articleSupport(), database: database, articlesZone: articlesZone)
		articlesZone.feedInfoDelegate = self
		
		Task {
			try await database.resetAllSelectedForProcessing()
		}

		// Check to see if this is a new account and initialize anything we need
		if account.externalID == nil {

			Task {

				do {
					let externalID = try await accountZone.findOrCreateAccount()
					account.externalID = externalID
					try await self.initialRefreshAll(for: account)
				} catch {
					os_log(.error, log: self.log, "Error adding account container: %@", error.localizedDescription)
				}

				accountZone.subscribeToZoneChanges()
				articlesZone.subscribeToZoneChanges()
			}
		}
	}
	
	func accountWillBeDeleted(_ account: Account) {
		accountZone.resetChangeToken()
		articlesZone.resetChangeToken()
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		return nil
	}

	// MARK: Suspend and Resume (for iOS)

	func suspendNetwork() {
		
//		refresher.suspend()
	}

	func suspendDatabase() {

		Task {
			await database.suspend()
		}
	}
	
	func resume() {

//		refresher.resume()

		Task {
			await database.resume()
		}
	}
}

private extension CloudKitAccountDelegate {
	
	func initialRefreshAll(for account: Account) async throws {

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await accountZone.fetchChangesInZone()

			let feeds = account.flattenedFeeds()
			refreshProgress.addTasks(feeds.count)

			try await refreshArticleStatus(for: account)

			try await combinedRefresh(account, feeds)
			account.metadata.lastArticleFetchEndTime = Date()
		} catch {
			processAccountError(account, error)
			refreshProgress.clear()
			throw error
		}
	}

	func standardRefreshAll(for account: Account) async throws {

		let intialFeedsCount = account.flattenedFeeds().count
		refreshProgress.addTasks(3 + intialFeedsCount)

		do {

			try await accountZone.fetchChangesInZone()
			refreshProgress.completeTask()

			let feeds = account.flattenedFeeds()
			refreshProgress.addTasks(feeds.count - intialFeedsCount)

			try await refreshArticleStatus(for: account)
			refreshProgress.completeTask()

			try await combinedRefresh(account, feeds)
			try await sendArticleStatus(for: account, showProgress: true)

			account.metadata.lastArticleFetchEndTime = Date()

			refreshProgress.clear()

		} catch {
			refreshProgress.completeTask()
			processAccountError(account, error)
			refreshProgress.clear()
			throw error
		}
	}

	func combinedRefresh(_ account: Account, _ feeds: Set<Feed>) async throws {

//		await refresher.refreshFeeds(feeds)
	}

	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		guard let containerExternalID = container.externalID else {
			throw CloudKitAccountDelegateError.invalidParameter
		}

		func addDeadFeed() async throws -> Feed {

			let feed = account.createFeed(with: editedName,
										  url: url.absoluteString,
										  feedID: url.absoluteString,
										  homePageURL: nil)
			container.addFeed(feed)

			do {
				let externalID = try await accountZone.createFeed(url: url.absoluteString,
																  name: editedName,
																  editedName: nil, homePageURL: nil,
																  containerExternalID: containerExternalID)
				feed.externalID = externalID
				return feed
			} catch {
				container.removeFeed(feed)
				throw error
			}
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		var feedSpecifiers: Set<FeedSpecifier>?

		do {
			feedSpecifiers = try await FeedFinder.find(url: url)
		} catch {
			if validateFeed {
				throw AccountError.createErrorNotFound
			} else {
				return try await addDeadFeed()
			}
		}

		guard let feedSpecifiers, let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers), let url = URL(string: bestFeedSpecifier.urlString) else {
			if validateFeed {
				throw AccountError.createErrorNotFound
			} else {
				return try await addDeadFeed()
			}
		}

		if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
			throw AccountError.createErrorAlreadySubscribed
		}

		let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		feed.editedName = editedName
		container.addFeed(feed)

		guard let parsedFeed = await InitialFeedDownloader.download(url) else {
			container.removeFeed(feed)
			throw AccountError.createErrorNotFound
		}

		do {
			try await account.update(feed: feed, with: parsedFeed)

			let externalID = try await accountZone.createFeed(url: bestFeedSpecifier.urlString,
															  name: parsedFeed.title,
															  editedName: editedName,
															  homePageURL: parsedFeed.homePageURL,
															  containerExternalID: containerExternalID)

			feed.externalID = externalID
			sendNewArticlesToTheCloud(account, feed)

			return feed

		} catch {
			container.removeFeed(feed)
			throw error
		}
	}

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: Feed) {

		Task {

			do {
				let articles = try await account.articles(for: .feed(feed))

				await self.storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>())
				self.refreshProgress.completeTask()

				try await self.sendArticleStatus(for: account, showProgress: true)
				try await self.articlesZone.fetchChangesInZone()

			} catch {
				os_log(.error, log: self.log, "CloudKit Feed send articles error: %@.", error.localizedDescription)
			}
		}
	}

	func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeeds(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolder(folder: folder)
			}
		}
	}
	
	func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) async {

		// New records with a read status aren't really new, they just didn't have the read article stored
		if let new {
			let filteredNew = new.filter { $0.status.read == false }
			await insertSyncStatuses(articles: filteredNew, statusKey: .new, flag: true)
		}

		await insertSyncStatuses(articles: updated, statusKey: .new, flag: false)
		await insertSyncStatuses(articles: deleted, statusKey: .deleted, flag: true)
	}
	
	func insertSyncStatuses(articles: Set<Article>?, statusKey: SyncStatus.Key, flag: Bool) async {

		guard let articles, !articles.isEmpty else {
			return
		}

		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		}

		try? await database.insertStatuses(Set(syncStatuses))
	}

	func sendArticleStatus(for account: Account, showProgress: Bool) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.sendArticleStatus(for: account, showProgress: showProgress) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func sendArticleStatus(for account: Account, showProgress: Bool, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let op = CloudKitSendStatusOperation(articlesZone: articlesZone,
											 refreshProgress: refreshProgress,
											 showProgress: showProgress,
											 database: database,
											 delegate: self)
		op.completionBlock = { mainThreadOperaion in
			Task { @MainActor in
				if mainThreadOperaion.isCanceled {
					completion(.failure(CloudKitAccountDelegateError.unknown))
				} else {
					completion(.success(()))
				}
			}
		}
		Task { @MainActor in
			mainThreadOperationQueue.add(op)
		}
	}
	

	func removeFeedFromCloud(for account: Account, with feed: Feed, from container: Container) async throws {

		guard let feedExternalID = feed.externalID, let containerExternalID = container.externalID else {
			return
		}

		refreshProgress.addTask()
		defer { refreshProgress.completeTask() }

		do {
			try await accountZone.removeFeed(externalID: feedExternalID, from: containerExternalID)

			try await articlesZone.deleteArticles(feedExternalID)
			feed.dropConditionalGetInfo()

		} catch {
			self.processAccountError(account, error)
			throw error
		}
	}
}

//extension CloudKitAccountDelegate: LocalAccountRefresherDelegate {
//
//	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: Feed) {
//
//		refreshProgress.completeTask()
//	}
//
//	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges, completion: @escaping () -> Void) {
//
//		Task { @MainActor in
//			await storeArticleChanges(new: articleChanges.newArticles,
//										  updated: articleChanges.updatedArticles,
//										  deleted: articleChanges.deletedArticles)
//		}
//	}
//}

extension CloudKitAccountDelegate: CloudKitFeedInfoDelegate {

	func feedExternalID(article: Article) -> String? {

		article.feed?.externalID
	}

	func feedURL(article: Article) -> String? {

		article.feed?.url
	}
}

extension CloudKitAccountDelegate: CloudKitSendStatusOperationDelegate {

	func cloudKitSendStatusOperation(_ : CloudKitSendStatusOperation, articlesFor articleIDs: Set<String>) async throws -> Set<Article> {

		guard let account else { return Set<Article>() }

		return try await account.articles(articleIDs: articleIDs)
	}

	func cloudKitSendStatusOperation(_ : CloudKitSendStatusOperation, userDidDeleteZone: Error) {

		// Delete feeds and folders

		guard let account else { return }

		account.removeFeeds(account.topLevelFeeds)

		for folder in account.folders ?? Set<Folder>() {
			account.removeFolder(folder: folder)
		}
	}
}

@MainActor final class CloudKitAcountZoneDelegate: CloudKitZoneDelegate {

	private typealias UnclaimedFeed = (url: URL, name: String?, editedName: String?, homePageURL: String?, feedExternalID: String)
	private var newUnclaimedFeeds = [String: [UnclaimedFeed]]()
	private var existingUnclaimedFeeds = [String: [Feed]]()

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	weak var account: Account?

	init(account: Account) {
		self.account = account
	}

	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {

		for deletedRecordKey in deleted {
			switch deletedRecordKey.recordType {
			case CloudKitAccountZone.CloudKitFeed.recordType:
				removeFeed(deletedRecordKey.recordID.externalID)
			case CloudKitAccountZone.CloudKitContainer.recordType:
				removeContainer(deletedRecordKey.recordID.externalID)
			default:
				assertionFailure("Unknown record type: \(deletedRecordKey.recordType)")
			}
		}

		for changedRecord in changed {
			switch changedRecord.recordType {
			case CloudKitAccountZone.CloudKitFeed.recordType:
				addOrUpdateFeed(changedRecord)
			case CloudKitAccountZone.CloudKitContainer.recordType:
				addOrUpdateContainer(changedRecord)
			default:
				assertionFailure("Unknown record type: \(changedRecord.recordType)")
			}
		}

		completion(.success(()))
	}
}

private extension CloudKitAcountZoneDelegate {

	func addOrUpdateFeed(_ record: CKRecord) {
		guard let account = account,
			  let urlString = record[CloudKitAccountZone.CloudKitFeed.Fields.url] as? String,
			  let containerExternalIDs = record[CloudKitAccountZone.CloudKitFeed.Fields.containerExternalIDs] as? [String],
			  let url = URL(string: urlString) else {
			return
		}

		let name = record[CloudKitAccountZone.CloudKitFeed.Fields.name] as? String
		let editedName = record[CloudKitAccountZone.CloudKitFeed.Fields.editedName] as? String
		let homePageURL = record[CloudKitAccountZone.CloudKitFeed.Fields.homePageURL] as? String

		if let feed = account.existingFeed(withExternalID: record.externalID) {
			updateFeed(feed, name: name, editedName: editedName, homePageURL: homePageURL, containerExternalIDs: containerExternalIDs)
		} else {
			for containerExternalID in containerExternalIDs {
				if let container = account.existingContainer(withExternalID: containerExternalID) {
					createFeedIfNecessary(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: record.externalID, container: container)
				} else {
					addNewUnclaimedFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: record.externalID, containerExternalID: containerExternalID)
				}
			}
		}
	}

	func removeFeed(_ externalID: String) {
		if let feed = account?.existingFeed(withExternalID: externalID), let containers = account?.existingContainers(withFeed: feed) {
			for container in containers {
				feed.dropConditionalGetInfo()
				container.removeFeed(feed)
			}
		}
	}

	func addOrUpdateContainer(_ record: CKRecord) {
		guard let account = account,
			  let name = record[CloudKitAccountZone.CloudKitContainer.Fields.name] as? String,
			  let isAccount = record[CloudKitAccountZone.CloudKitContainer.Fields.isAccount] as? String,
			  isAccount != "1" else {
			return
		}

		var folder = account.existingFolder(withExternalID: record.externalID)
		folder?.name = name

		if folder == nil {
			folder = account.ensureFolder(with: name)
			folder?.externalID = record.externalID
		}

		guard let container = folder, let containerExternalID = container.externalID else { return }

		if let newUnclaimedFeeds = newUnclaimedFeeds[containerExternalID] {
			for newUnclaimedFeed in newUnclaimedFeeds {
				createFeedIfNecessary(url: newUnclaimedFeed.url,
									  name: newUnclaimedFeed.name,
									  editedName: newUnclaimedFeed.editedName,
									  homePageURL: newUnclaimedFeed.homePageURL,
									  feedExternalID: newUnclaimedFeed.feedExternalID,
									  container: container)
			}

			self.newUnclaimedFeeds.removeValue(forKey: containerExternalID)
		}

		if let existingUnclaimedFeeds = existingUnclaimedFeeds[containerExternalID] {
			for existingUnclaimedFeed in existingUnclaimedFeeds {
				container.addFeed(existingUnclaimedFeed)
			}
			self.existingUnclaimedFeeds.removeValue(forKey: containerExternalID)
		}
	}

	func removeContainer(_ externalID: String) {
		if let folder = account?.existingFolder(withExternalID: externalID) {
			account?.removeFolder(folder: folder)
		}
	}

	func updateFeed(_ feed: Feed, name: String?, editedName: String?, homePageURL: String?, containerExternalIDs: [String]) {
		guard let account = account else { return }

		feed.name = name
		feed.editedName = editedName
		feed.homePageURL = homePageURL

		let existingContainers = account.existingContainers(withFeed: feed)
		let existingContainerExternalIDs = existingContainers.compactMap { $0.externalID }

		let diff = containerExternalIDs.difference(from: existingContainerExternalIDs)

		for change in diff {
			switch change {
			case .remove(_, let externalID, _):
				if let container = existingContainers.first(where: { $0.externalID == externalID }) {
					container.removeFeed(feed)
				}
			case .insert(_, let externalID, _):
				if let container = account.existingContainer(withExternalID: externalID) {
					container.addFeed(feed)
				} else {
					addExistingUnclaimedFeed(feed, containerExternalID: externalID)
				}
			}
		}
	}

	func createFeedIfNecessary(url: URL, name: String?, editedName: String?, homePageURL: String?, feedExternalID: String, container: Container) {
		guard let account = account else { return  }

		if account.existingFeed(withExternalID: feedExternalID) != nil {
			return
		}

		let feed = account.createFeed(with: name, url: url.absoluteString, feedID: url.absoluteString, homePageURL: homePageURL)
		feed.editedName = editedName
		feed.externalID = feedExternalID
		container.addFeed(feed)
	}

	func addNewUnclaimedFeed(url: URL, name: String?, editedName: String?, homePageURL: String?, feedExternalID: String, containerExternalID: String) {
		if var unclaimedFeeds = self.newUnclaimedFeeds[containerExternalID] {
			unclaimedFeeds.append(UnclaimedFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: feedExternalID))
			self.newUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		} else {
			var unclaimedFeeds = [UnclaimedFeed]()
			unclaimedFeeds.append(UnclaimedFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: feedExternalID))
			self.newUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		}
	}

	func addExistingUnclaimedFeed(_ feed: Feed, containerExternalID: String) {
		if var unclaimedFeeds = self.existingUnclaimedFeeds[containerExternalID] {
			unclaimedFeeds.append(feed)
			self.existingUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		} else {
			var unclaimedFeeds = [Feed]()
			unclaimedFeeds.append(feed)
			self.existingUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		}
	}
}
