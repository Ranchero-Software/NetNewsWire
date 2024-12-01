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

enum CloudKitAccountDelegateError: LocalizedError {
	case invalidParameter
	case unknown

	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

final class CloudKitAccountDelegate: AccountDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	private let database: SyncDatabase

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
		self.database = SyncDatabase(databaseFilePath: databaseFilePath)

		self.refresher = LocalAccountRefresher()
		self.refresher.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: refresher.downloadProgress)
		NotificationCenter.default.addObserver(self, selector: #selector(syncProgressDidChange(_:)), name: .DownloadProgressDidChange, object: syncProgress)
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		let op = CloudKitRemoteNotificationOperation(accountZone: accountZone, articlesZone: articlesZone, userInfo: userInfo)
		op.completionBlock = { mainThreadOperaion in
			completion()
		}
		mainThreadOperationQueue.add(op)
	}

	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {

		guard refreshProgress.isComplete else {
			completion(.success(()))
			return
		}

		let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com")
		var flags = SCNetworkReachabilityFlags()
		guard SCNetworkReachabilityGetFlags(reachability!, &flags), flags.contains(.reachable) else {
			completion(.success(()))
			return
		}

		standardRefreshAll(for: account, completion: completion)
	}

	func syncArticleStatus(for account: Account, completion: ((Result<Void, Error>) -> Void)? = nil) {
		sendArticleStatus(for: account) { result in
			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						completion?(.success(()))
					case .failure(let error):
						completion?(.failure(error))
					}
				}
			case .failure(let error):
				completion?(.failure(error))
			}
		}
	}

	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		sendArticleStatus(for: account, showProgress: false, completion: completion)
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

	func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {

		guard refreshProgress.isComplete else {
			completion(.success(()))
			return
		}

		var fileData: Data?

		do {
			fileData = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}

		guard let opmlData = fileData else {
			completion(.success(()))
			return
		}

		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		var opmlDocument: RSOPMLDocument?

		do {
			opmlDocument = try RSOPMLParser.parseOPML(with: parserData)
		} catch {
			completion(.failure(error))
			return
		}

		guard let loadDocument = opmlDocument else {
			completion(.success(()))
			return
		}

		guard let opmlItems = loadDocument.children, let rootExternalID = account.externalID else {
			return
		}

		let normalizedItems = OPMLNormalizer.normalize(opmlItems)
		
		syncProgress.addToNumberOfTasksAndRemaining(1)
		self.accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems) { _ in
			self.syncProgress.completeTask()
			self.standardRefreshAll(for: account, completion: completion)
		}
	}

	func createWebFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}

		let editedName = name == nil || name!.isEmpty ? nil : name

		createRSSWebFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed, completion: completion)
	}

	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let editedName = name.isEmpty ? nil : name
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.renameWebFeed(feed, editedName: editedName) { result in
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

	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		removeWebFeedFromCloud(for: account, with: feed, from: container) { result in
			switch result {
			case .success:
				account.clearWebFeedMetadata(feed)
				container.removeWebFeed(feed)
				completion(.success(()))
			case .failure(let error):
				switch error {
				case CloudKitZoneError.corruptAccount:
					// We got into a bad state and should remove the feed to clear up the bad data
					account.clearWebFeedMetadata(feed)
					container.removeWebFeed(feed)
				default:
					completion(.failure(error))
				}
			}
		}
	}

	func moveWebFeed(for account: Account, with feed: WebFeed, from fromContainer: Container, to toContainer: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.moveWebFeed(feed, from: fromContainer, to: toContainer) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				fromContainer.removeWebFeed(feed)
				toContainer.addWebFeed(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	func addWebFeed(for account: Account, with feed: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.addWebFeed(feed, to: container) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				container.addWebFeed(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	func restoreWebFeed(for account: Account, feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		createWebFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.createFolder(name: name) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success(let externalID):
				if let folder = account.ensureFolder(with: name) {
					folder.externalID = externalID
					completion(.success(folder))
				} else {
					completion(.failure(FeedbinAccountDelegateError.invalidParameter))
				}
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
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

	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		
		syncProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.findWebFeedExternalIDs(for: folder) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success(let webFeedExternalIDs):

				let webFeeds = webFeedExternalIDs.compactMap { account.existingWebFeed(withExternalID: $0) }
				let group = DispatchGroup()
				var errorOccurred = false

				for webFeed in webFeeds {
					group.enter()
					self.removeWebFeedFromCloud(for: account, with: webFeed, from: folder) { result in
						group.leave()
						if case .failure(let error) = result {
							os_log(.error, log: self.log, "Remove folder, remove webfeed error: %@.", error.localizedDescription)
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
								account.removeFolder(folder)
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

	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let name = folder.name else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}

		let feedsToRestore = folder.topLevelWebFeeds
		syncProgress.addToNumberOfTasksAndRemaining(1 + feedsToRestore.count)

		accountZone.createFolder(name: name) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success(let externalID):
				folder.externalID = externalID
				account.addFolder(folder)

				let group = DispatchGroup()
				for feed in feedsToRestore {

					folder.topLevelWebFeeds.remove(feed)

					group.enter()
					self.restoreWebFeed(for: account, feed: feed, container: folder) { result in
						self.syncProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							break
						case .failure(let error):
							os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
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

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in
			switch result {
			case .success(let articles):
				let syncStatuses = articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				}

				self.database.insertStatuses(syncStatuses) { _ in
					self.database.selectPendingCount { result in
						if let count = try? result.get(), count > 100 {
							self.sendArticleStatus(for: account, showProgress: false)  { _ in }
						}
						completion(.success(()))
					}
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account

		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, articlesZone: articlesZone)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account, database: database, articlesZone: articlesZone)

		database.resetAllSelectedForProcessing()

		// Check to see if this is a new account and initialize anything we need
		if account.externalID == nil {
			accountZone.findOrCreateAccount() { result in
				switch result {
				case .success(let externalID):
					account.externalID = externalID
					self.initialRefreshAll(for: account) { _ in }
				case .failure(let error):
					os_log(.error, log: self.log, "Error adding account container: %@", error.localizedDescription)
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

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, completion: (Result<Credentials?, Error>) -> Void) {
		return completion(.success(nil))
	}

	// MARK: - Suspend and Resume (for iOS)

	func suspendNetwork() {
		refresher.suspend()
	}

	func suspendDatabase() {
		database.suspend()
	}

	func resume() {
		refresher.resume()
		database.resume()
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
			self.syncProgress.clear()
			completion(.failure(error))
		}

		syncProgress.addToNumberOfTasksAndRemaining(3)
		accountZone.fetchChangesInZone() { result in
			self.syncProgress.completeTask()

			let webFeeds = account.flattenedWebFeeds()

			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					self.syncProgress.completeTask()
					switch result {
					case .success:

						self.combinedRefresh(account, webFeeds) {
							self.syncProgress.clear()
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

	func standardRefreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		syncProgress.addToNumberOfTasksAndRemaining(3)

		func fail(_ error: Error) {
			self.processAccountError(account, error)
			self.syncProgress.clear()
			completion(.failure(error))
		}

		accountZone.fetchChangesInZone() { result in
			switch result {
			case .success:
				
				self.syncProgress.completeTask()
				let webFeeds = account.flattenedWebFeeds()

				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						self.syncProgress.completeTask()
						self.combinedRefresh(account, webFeeds) {
							self.sendArticleStatus(for: account, showProgress: true) { _ in
								self.syncProgress.clear()
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

	func combinedRefresh(_ account: Account, _ webFeeds: Set<WebFeed>, completion: @escaping () -> Void) {

		refresher.refreshFeeds(webFeeds, completion: completion)
	}

	func createRSSWebFeed(for account: Account, url: URL, editedName: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<WebFeed, Error>) -> Void) {

		func addDeadFeed() {
			let feed = account.createWebFeed(with: editedName, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
			container.addWebFeed(feed)

			self.accountZone.createWebFeed(url: url.absoluteString,
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
					container.removeWebFeed(feed)
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

				if account.hasWebFeed(withURL: bestFeedSpecifier.urlString) {
					self.syncProgress.completeTasks(4)
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}

				let feed = account.createWebFeed(with: nil, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
				feed.editedName = editedName
				container.addWebFeed(feed)

				InitialFeedDownloader.download(url) { parsedFeed in
					self.syncProgress.completeTask()

					if let parsedFeed = parsedFeed {
						account.update(feed, with: parsedFeed) { result in
							switch result {
							case .success:

								self.accountZone.createWebFeed(url: bestFeedSpecifier.urlString,
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
										container.removeWebFeed(feed)
										self.syncProgress.completeTasks(2)
										completion(.failure(error))
									}
								}

							case .failure(let error):
								container.removeWebFeed(feed)
								self.syncProgress.completeTasks(3)
								completion(.failure(error))
							}

						}
					} else {
						self.syncProgress.completeTasks(3)
						container.removeWebFeed(feed)
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

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: WebFeed) {
		account.fetchArticlesAsync(.webFeed(feed)) { result in
			switch result {
			case .success(let articles):
				self.storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>()) {
					self.syncProgress.completeTask()
					self.sendArticleStatus(for: account, showProgress: true) { result in
						switch result {
						case .success:
							self.articlesZone.fetchChangesInZone() { _ in }
						case .failure(let error):
							os_log(.error, log: self.log, "CloudKit Feed send articles error: %@.", error.localizedDescription)
						}
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "CloudKit Feed send articles error: %@.", error.localizedDescription)
			}
		}
	}

	func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeeds(account.topLevelWebFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolder(folder)
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
		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		}
		database.insertStatuses(syncStatuses) { _ in
			completion()
		}
	}

	func sendArticleStatus(for account: Account, showProgress: Bool, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let op = CloudKitSendStatusOperation(account: account,
											 articlesZone: articlesZone,
											 refreshProgress: refreshProgress,
											 showProgress: showProgress,
											 database: database)
		op.completionBlock = { mainThreadOperaion in
			if mainThreadOperaion.isCanceled {
				completion(.failure(CloudKitAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}
		mainThreadOperationQueue.add(op)
	}


	func removeWebFeedFromCloud(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		syncProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.removeWebFeed(feed, from: container) { result in
			self.syncProgress.completeTask()
			switch result {
			case .success:
				guard let webFeedExternalID = feed.externalID else {
					completion(.success(()))
					return
				}
				self.articlesZone.deleteArticles(webFeedExternalID) { result in
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
