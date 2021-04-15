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
		
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		database = SyncDatabase(databaseFilePath: databaseFilePath)
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
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		self.accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems) { _ in
			self.refreshProgress.completeTask()
			self.standardRefreshAll(for: account, completion: completion)
		}
		
	}
	
	func createWebFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		guard let url = URL(string: urlString), let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		let editedName = name == nil || name!.isEmpty ? nil : name

		// Username should be part of the URL on new feed adds
		if let feedProvider = FeedProviderManager.shared.best(for: urlComponents) {
			createProviderWebFeed(for: account, urlComponents: urlComponents, editedName: editedName, container: container, feedProvider: feedProvider, completion: completion)
		} else {
			createRSSWebFeed(for: account, url: url, editedName: editedName, container: container, validateFeed: validateFeed, completion: completion)
		}
		
	}

	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let editedName = name.isEmpty ? nil : name
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.renameWebFeed(feed, editedName: editedName) { result in
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
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.moveWebFeed(feed, from: fromContainer, to: toContainer) { result in
			self.refreshProgress.completeTask()
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
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.addWebFeed(feed, to: container) { result in
			self.refreshProgress.completeTask()
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
	
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
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
	
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		
		refreshProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.findWebFeedExternalIDs(for: folder) { result in
			self.refreshProgress.completeTask()
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
							self.refreshProgress.completeTask()
							completion(.failure(CloudKitAccountDelegateError.unknown))
							return
						}
						
						self.accountZone.removeFolder(folder) { result in
							self.refreshProgress.completeTask()
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
				self.refreshProgress.completeTask()
				self.refreshProgress.completeTask()
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
		refreshProgress.addToNumberOfTasksAndRemaining(1 + feedsToRestore.count)
		
		accountZone.createFolder(name: name) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let externalID):
				folder.externalID = externalID
				account.addFolder(folder)
				
				let group = DispatchGroup()
				for feed in feedsToRestore {
					
					folder.topLevelWebFeeds.remove(feed)

					group.enter()
					self.restoreWebFeed(for: account, feed: feed, container: folder) { result in
						self.refreshProgress.completeTask()
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
		
		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, refreshProgress: refreshProgress, articlesZone: articlesZone)
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

	// MARK: Suspend and Resume (for iOS)

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

			let webFeeds = account.flattenedWebFeeds()
			self.refreshProgress.addToNumberOfTasksAndRemaining(webFeeds.count)

			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success:
						
						self.combinedRefresh(account, webFeeds) { result in
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
		
		let intialWebFeedsCount = account.flattenedWebFeeds().count
		refreshProgress.addToNumberOfTasksAndRemaining(3 + intialWebFeedsCount)

		func fail(_ error: Error) {
			self.processAccountError(account, error)
			self.refreshProgress.clear()
			completion(.failure(error))
		}
		
		accountZone.fetchChangesInZone() { result in
			switch result {
			case .success:
				
				self.refreshProgress.completeTask()
				let webFeeds = account.flattenedWebFeeds()
				self.refreshProgress.addToNumberOfTasksAndRemaining(webFeeds.count - intialWebFeedsCount)
				
				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						self.refreshProgress.completeTask()
						self.combinedRefresh(account, webFeeds) { result in
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

	func combinedRefresh(_ account: Account, _ webFeeds: Set<WebFeed>, completion: @escaping (Result<Void, Error>) -> Void) {
		
		var refresherWebFeeds = Set<WebFeed>()
		let group = DispatchGroup()
		var feedProviderError: Error? = nil
		
		for webFeed in webFeeds {
			if let components = URLComponents(string: webFeed.url), let feedProvider = FeedProviderManager.shared.best(for: components) {
				group.enter()
				feedProvider.refresh(webFeed) { result in
					switch result {
					case .success(let parsedItems):
						
						account.update(webFeed.webFeedID, with: parsedItems) { result in
							switch result {
							case .success(let articleChanges):
								self.storeArticleChanges(new: articleChanges.newArticles, updated: articleChanges.updatedArticles, deleted: articleChanges.deletedArticles) {
									self.refreshProgress.completeTask()
									group.leave()
								}
							case .failure(let error):
								os_log(.error, log: self.log, "CloudKit Feed refresh update error: %@.", error.localizedDescription)
								self.refreshProgress.completeTask()
								group.leave()
							}
							
						}

					case .failure(let error):
						os_log(.error, log: self.log, "CloudKit Feed refresh error: %@.", error.localizedDescription)
						feedProviderError = error
						self.refreshProgress.completeTask()
						group.leave()
					}
				}
			} else {
				refresherWebFeeds.insert(webFeed)
			}
		}
		
		group.enter()
		refresher.refreshFeeds(refresherWebFeeds) {
			group.leave()
		}
		
		group.notify(queue: DispatchQueue.main) {
			if let error = feedProviderError {
				completion(.failure(error))
			} else {
				completion(.success(()))
			}
		}

	}

	func createProviderWebFeed(for account: Account, urlComponents: URLComponents, editedName: String?, container: Container, feedProvider: FeedProvider, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(5)
		
		feedProvider.metaData(urlComponents) { result in
			self.refreshProgress.completeTask()
			switch result {
				
			case .success(let metaData):

				guard let urlString = urlComponents.url?.absoluteString else {
					self.refreshProgress.completeTasks(4)
					completion(.failure(AccountError.createErrorNotFound))
					return
				}
				
				self.accountZone.createWebFeed(url: urlString, name: metaData.name, editedName: editedName, homePageURL: metaData.homePageURL, container: container) { result in

					self.refreshProgress.completeTask()
					switch result {
					case .success(let externalID):

						let feed = account.createWebFeed(with: metaData.name, url: urlString, webFeedID: urlString, homePageURL: metaData.homePageURL)
						feed.editedName = editedName
						feed.externalID = externalID
						container.addWebFeed(feed)

						feedProvider.refresh(feed) { result in
							self.refreshProgress.completeTask()
							switch result {
							case .success(let parsedItems):
								
								account.update(urlString, with: parsedItems) { result in
									switch result {
									case .success:
										self.sendNewArticlesToTheCloud(account, feed)
										self.refreshProgress.clear()
										completion(.success(feed))
									case .failure(let error):
										self.refreshProgress.completeTasks(2)
										completion(.failure(error))
									}
									
								}
								
							case .failure:
								self.refreshProgress.completeTasks(3)
								completion(.failure(AccountError.createErrorNotFound))
							}
						}
						
					case .failure(let error):
						self.refreshProgress.completeTasks(4)
						completion(.failure(error))
					}
				}

			case .failure:
				self.refreshProgress.completeTasks(4)
				completion(.failure(AccountError.createErrorNotFound))
			}
		}
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

				self.refreshProgress.completeTask()
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
				
				if account.hasWebFeed(withURL: bestFeedSpecifier.urlString) {
					self.refreshProgress.completeTasks(4)
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				let feed = account.createWebFeed(with: nil, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
				feed.editedName = editedName
				container.addWebFeed(feed)

				InitialFeedDownloader.download(url) { parsedFeed in
					self.refreshProgress.completeTask()

					if let parsedFeed = parsedFeed {
						account.update(feed, with: parsedFeed) { result in
							switch result {
							case .success:
								
								self.accountZone.createWebFeed(url: bestFeedSpecifier.urlString,
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
										container.removeWebFeed(feed)
										self.refreshProgress.completeTasks(2)
										completion(.failure(error))
									}
									
								}

							case .failure(let error):
								container.removeWebFeed(feed)
								self.refreshProgress.completeTasks(3)
								completion(.failure(error))
							}
							
						}
					} else {
						self.refreshProgress.completeTasks(3)
						container.removeWebFeed(feed)
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

	func sendNewArticlesToTheCloud(_ account: Account, _ feed: WebFeed) {
		account.fetchArticlesAsync(.webFeed(feed)) { result in
			switch result {
			case .success(let articles):
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
		refreshProgress.addToNumberOfTasksAndRemaining(2)
		accountZone.removeWebFeed(feed, from: container) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				guard let webFeedExternalID = feed.externalID else {
					completion(.success(()))
					return
				}
				self.articlesZone.deleteArticles(webFeedExternalID) { result in
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
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: WebFeed) {
		refreshProgress.completeTask()
	}
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges, completion: @escaping () -> Void) {
		self.storeArticleChanges(new: articleChanges.newArticles,
								 updated: articleChanges.updatedArticles,
								 deleted: articleChanges.deletedArticles,
								 completion: completion)
	}
	
}

