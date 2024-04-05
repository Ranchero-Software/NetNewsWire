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
import Articles
import ArticlesDatabase
import Web
import Secrets
import Core
import CloudKitExtras

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

	private lazy var refresher: LocalAccountRefresher = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		return refresher
	}()

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
		Task { @MainActor in
			mainThreadOperationQueue.add(op)
		}
	}
	
	func refreshAll(for account: Account) async throws {
		
		guard refreshProgress.isComplete else {
			return
		}

		let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com")
		var flags = SCNetworkReachabilityFlags()
		guard SCNetworkReachabilityGetFlags(reachability!, &flags), flags.contains(.reachable) else {
			return
		}
			
		try await withCheckedThrowingContinuation { continuation in
			self.standardRefreshAll(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
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

		try await withCheckedThrowingContinuation { continuation in
			self.importOPML(for: account, opmlFile: opmlFile) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
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
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		self.accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems) { _ in
			self.refreshProgress.completeTask()
			self.standardRefreshAll(for: account, completion: completion)
		}
		
	}
	
	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {

		try await withCheckedThrowingContinuation { continuation in
			self.createFeed(for: account, url: url, name: name, container: container, validateFeed: validateFeed) { result in
				switch result {
				case .success(let feed):
					continuation.resume(returning: feed)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		let editedName = name == nil || name!.isEmpty ? nil : name

		createRSSFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed, completion: completion)
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.renameFeed(for: account, with: feed, to: name) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let editedName = name.isEmpty ? nil : name
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.renameFeed(feed, editedName: editedName) { result in
			self.refreshProgress.completeTask()
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

	func removeFeed(for account: Account, with feed: Feed, from container: any Container) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.removeFeed(for: account, with: feed, from: container) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		removeFeedFromCloud(for: account, with: feed, from: container) { result in
			switch result {
			case .success:
				account.clearFeedMetadata(feed)
				container.removeFeed(feed)
				completion(.success(()))
			case .failure(let error):
				switch error {
				case CloudKitZoneError.corruptAccount:
					// We got into a bad state and should remove the feed to clear up the bad data
					account.clearFeedMetadata(feed)
					container.removeFeed(feed)
				default:
					completion(.failure(error))
				}
			}
		}
	}
	
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.moveFeed(for: account, with: feed, from: from, to: to) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private  func moveFeed(for account: Account, with feed: Feed, from fromContainer: Container, to toContainer: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.moveFeed(feed, from: fromContainer, to: toContainer) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				fromContainer.removeFeed(feed)
				toContainer.addFeed(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}
	
	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.addFeed(for: account, with: feed, to: container) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.addFeed(feed, to: container) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				container.addFeed(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}
	
	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {

		try await withCheckedThrowingContinuation { continuation in

			self.createFolder(for: account, name: name) { result in
				switch result {
				case .success(let folder):
					continuation.resume(returning: folder)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.createFolder(name: name) { result in
			self.refreshProgress.completeTask()
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
	
	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.renameFolder(for: account, with: folder, to: name) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.renameFolder(folder, to: name) { result in
			self.refreshProgress.completeTask()
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
	
	func removeFolder(for account: Account, with folder: Folder) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.removeFolder(for: account, with: folder) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {

		refreshProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.findFeedExternalIDs(for: folder) { result in
			self.refreshProgress.completeTask()
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
							os_log(.error, log: self.log, "Remove folder, remove feed error: %@.", error.localizedDescription)
							errorOccurred = true
						}
					}
				}
				
				group.notify(queue: DispatchQueue.global(qos: .background)) {
					DispatchQueue.main.async {
						guard !errorOccurred else {
							self.refreshProgress.completeTask()
							completion(.failure(CloudKitAccountDelegateError.unknown))
							return
						}
						
						self.accountZone.removeFolder(folder) { result in
							self.refreshProgress.completeTask()
							switch result {
							case .success:
								account.removeFolder(folder: folder)
								completion(.success(()))
							case .failure(let error):
								completion(.failure(error))
							}
						}
					}
				}
				
			case .failure(let error):
				self.refreshProgress.completeTask()
				self.refreshProgress.completeTask()
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
		
	}
	
	func restoreFolder(for account: Account, folder: Folder) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.restoreFolder(for: account, folder: folder) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let name = folder.name else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		let feedsToRestore = folder.topLevelFeeds
		refreshProgress.addToNumberOfTasksAndRemaining(1 + feedsToRestore.count)
		
		accountZone.createFolder(name: name) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let externalID):
				folder.externalID = externalID
				account.addFolder(folder)
				
				let group = DispatchGroup()
				for feed in feedsToRestore {
					
					folder.topLevelFeeds.remove(feed)

					group.enter()

					Task { @MainActor in
						do {
							try await self.restoreFeed(for: account, feed: feed, container: folder)
						} catch {
							os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
						}
						group.leave()
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

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.markArticles(for: account, articles: articles, statusKey: statusKey, flag: flag) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in
			switch result {
			case .success(let articles):
				let syncStatuses = articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				}

				Task { @MainActor in
					try? await self.database.insertStatuses(syncStatuses)
					if let count = try? await self.database.selectPendingCount(), count > 100 {
						self.sendArticleStatus(for: account, showProgress: false)  { _ in }
					}
					completion(.success(()))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
		
		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, refreshProgress: refreshProgress, articlesZone: articlesZone)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account, database: database, articlesZone: articlesZone)
		
		Task {
			try await database.resetAllSelectedForProcessing()
		}

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

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		return nil
	}

	// MARK: Suspend and Resume (for iOS)

	func suspendNetwork() {
		
		refresher.suspend()
	}

	func suspendDatabase() {

		Task {
			await database.suspend()
		}
	}
	
	func resume() {

		refresher.resume()

		Task {
			await database.resume()
		}
	}
}

private extension CloudKitAccountDelegate {
	
	func initialRefreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		func fail(_ error: Error) {
			self.processAccountError(account, error)
			self.refreshProgress.clear()
			completion(.failure(error))
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(3)
		accountZone.fetchChangesInZone() { result in
			self.refreshProgress.completeTask()

			let feeds = account.flattenedFeeds()
			self.refreshProgress.addToNumberOfTasksAndRemaining(feeds.count)

			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success:
						
						self.combinedRefresh(account, feeds) { result in
							self.refreshProgress.clear()
							switch result {
							case .success:
								account.metadata.lastArticleFetchEndTime = Date()
							case .failure(let error):
								fail(error)
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

	func standardRefreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		let intialFeedsCount = account.flattenedFeeds().count
		refreshProgress.addToNumberOfTasksAndRemaining(3 + intialFeedsCount)

		func fail(_ error: Error) {
			self.processAccountError(account, error)
			self.refreshProgress.clear()
			completion(.failure(error))
		}
		
		accountZone.fetchChangesInZone() { result in
			switch result {
			case .success:
				
				self.refreshProgress.completeTask()
				let feeds = account.flattenedFeeds()
				self.refreshProgress.addToNumberOfTasksAndRemaining(feeds.count - intialFeedsCount)
				
				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						self.refreshProgress.completeTask()
						self.combinedRefresh(account, feeds) { result in
							self.sendArticleStatus(for: account, showProgress: true) { _ in
								self.refreshProgress.clear()
								if case .failure(let error) = result {
									fail(error)
								} else {
									account.metadata.lastArticleFetchEndTime = Date()
									completion(.success(()))
								}
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

	func combinedRefresh(_ account: Account, _ feeds: Set<Feed>, completion: @escaping (Result<Void, Error>) -> Void) {
		
		Task { @MainActor in
			await self.refresher.refreshFeeds(feeds)
			completion(.success(()))
		}
	}
	
	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {

		func addDeadFeed() {
			let feed = account.createFeed(with: editedName, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
			container.addFeed(feed)

			self.accountZone.createFeed(url: url.absoluteString,
										   name: editedName,
										   editedName: nil,
										   homePageURL: nil,
										   container: container) { result in

				self.refreshProgress.completeTask()
				switch result {
				case .success(let externalID):
					feed.externalID = externalID
					completion(.success(feed))
				case .failure(let error):
					container.removeFeed(feed)
					completion(.failure(error))
				}
			}
		}

		refreshProgress.addToNumberOfTasksAndRemaining(5)
		FeedFinder.find(url: url) { result in
			
			self.refreshProgress.completeTask()
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers), let url = URL(string: bestFeedSpecifier.urlString) else {
					self.refreshProgress.completeTasks(3)
					if validateFeed {
						self.refreshProgress.completeTask()
						completion(.failure(AccountError.createErrorNotFound))
					} else {
						addDeadFeed()
					}
					return
				}
				
				if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
					self.refreshProgress.completeTasks(4)
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
				feed.editedName = editedName
				container.addFeed(feed)

				InitialFeedDownloader.download(url) { parsedFeed in
					self.refreshProgress.completeTask()

					if let parsedFeed {

						Task { @MainActor in

							do {
								try await account.update(feed: feed, with: parsedFeed)

								self.accountZone.createFeed(url: bestFeedSpecifier.urlString,
															name: parsedFeed.title,
															editedName: editedName,
															homePageURL: parsedFeed.homePageURL,
															container: container) { result in

									self.refreshProgress.completeTask()
									switch result {
									case .success(let externalID):
										feed.externalID = externalID
										self.sendNewArticlesToTheCloud(account, feed)
										completion(.success(feed))
									case .failure(let error):
										container.removeFeed(feed)
										self.refreshProgress.completeTasks(2)
										completion(.failure(error))
									}

								}
							} catch {
								container.removeFeed(feed)
								self.refreshProgress.completeTasks(3)
								completion(.failure(error))
							}
						}
					} else {
						self.refreshProgress.completeTasks(3)
						container.removeFeed(feed)
						completion(.failure(AccountError.createErrorNotFound))
					}	
				}
								
			case .failure:
				self.refreshProgress.completeTasks(3)
				if validateFeed {
					self.refreshProgress.completeTask()
					completion(.failure(AccountError.createErrorNotFound))
					return
				} else {
					addDeadFeed()
				}
			}
		}
	}

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: Feed) {

		Task { @MainActor in

			do {
				let articles = try await account.articles(for: .feed(feed))
				self.storeArticleChanges(new: articles, updated: Set<Article>(), deleted: Set<Article>()) {
					self.refreshProgress.completeTask()
					self.sendArticleStatus(for: account, showProgress: true) { result in
						switch result {
						case .success:
							self.articlesZone.fetchChangesInZone() { _ in }
						case .failure(let error):
							os_log(.error, log: self.log, "CloudKit Feed send articles error: %@.", error.localizedDescription)
						}
					}
				}

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
	
	func storeArticleChanges(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?, completion: @escaping () -> Void) {
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
				completion()
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

		Task { @MainActor in

			try? await self.database.insertStatuses(syncStatuses)
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
	

	func removeFeedFromCloud(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.removeFeed(feed, from: container) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				guard let feedExternalID = feed.externalID else {
					completion(.success(()))
					return
				}
				self.articlesZone.deleteArticles(feedExternalID) { result in
					feed.dropConditionalGetInfo()
					self.refreshProgress.completeTask()
					completion(result)
				}
			case .failure(let error):
				self.refreshProgress.completeTask()
				self.processAccountError(account, error)
				completion(.failure(error))
			}
		}
	}
	
}

extension CloudKitAccountDelegate: LocalAccountRefresherDelegate {
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: Feed) {
		refreshProgress.completeTask()
	}
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges, completion: @escaping () -> Void) {
		self.storeArticleChanges(new: articleChanges.newArticles,
								 updated: articleChanges.updatedArticles,
								 deleted: articleChanges.deletedArticles,
								 completion: completion)
	}
	
}

