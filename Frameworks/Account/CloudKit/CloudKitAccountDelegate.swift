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

public enum CloudKitAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class CloudKitAccountDelegate: AccountDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	private let database: SyncDatabase
	
	private let container: CKContainer = {
		let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as! String
		return CKContainer(identifier: "iCloud.\(orgID).NetNewsWire")
	}()
	
	private lazy var zones: [CloudKitZone] = [accountZone, articlesZone]
	private let accountZone: CloudKitAccountZone
	private let articlesZone: CloudKitArticlesZone
	
	weak var account: Account?
	
	private lazy var refresher: LocalAccountRefresher = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		return refresher
	}()

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
		os_log(.debug, log: log, "Processing remote notification...")

		let group = DispatchGroup()
		
		zones.forEach { zone in
			group.enter()
			zone.receiveRemoteNotification(userInfo: userInfo) {
				group.leave()
			}
		}
		
		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done processing remote notification...")
			completion()
		}
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

	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		os_log(.debug, log: log, "Sending article statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				guard syncStatuses.count > 0 else {
					completion(.success(()))
					return
				}
				
				let articleIDs = syncStatuses.map({ $0.articleID })
				account.fetchArticlesAsync(.articleIDs(Set(articleIDs))) { result in
					
					func processWithArticles(_ articles: Set<Article>) {
						
						self.articlesZone.sendArticleStatus(syncStatuses, articles: articles) { result in
							switch result {
							case .success:
								self.database.deleteSelectedForProcessing(syncStatuses.map({ $0.articleID }) )
								os_log(.debug, log: self.log, "Done sending article statuses.")
								completion(.success(()))
							case .failure(let error):
								self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID }) )
								self.processAccountError(account, error)
								completion(.failure(error))
							}
						}
						
					}

					switch result {
					case .success(let articles):
						processWithArticles(articles)
					case .failure(let databaseError):
						completion(.failure(databaseError))
					}

				}
				
			}

			switch result {
			case .success(let syncStatuses):
				processStatuses(syncStatuses)
			case .failure(let databaseError):
				completion(.failure(databaseError))
			}
		}
	}
	
	
	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		os_log(.debug, log: log, "Refreshing article statuses...")
		
		articlesZone.refreshArticleStatus() { result in
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
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
		
		// TODO: remove duplicates created by import
		
		self.accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems) { _ in
			self.initialRefreshAll(for: account, completion: completion)
		}
		
	}
	
	func createWebFeed(for account: Account, url urlString: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		let editedName = name == nil || name!.isEmpty ? nil : name

		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		BatchUpdate.shared.start()
		refreshProgress.addToNumberOfTasksAndRemaining(3)
		FeedFinder.find(url: url) { result in
			
			self.refreshProgress.completeTask()
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers), let url = URL(string: bestFeedSpecifier.urlString) else {
					BatchUpdate.shared.end()
					self.refreshProgress.clear()
					completion(.failure(AccountError.createErrorNotFound))
					return
				}
				
				if account.hasWebFeed(withURL: bestFeedSpecifier.urlString) {
					BatchUpdate.shared.end()
					self.refreshProgress.clear()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				self.accountZone.createWebFeed(url: bestFeedSpecifier.urlString, editedName: editedName, container: container) { result in

					self.refreshProgress.completeTask()
					switch result {
					case .success(let externalID):
						
						let feed = account.createWebFeed(with: nil, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
						feed.editedName = editedName
						feed.externalID = externalID
						container.addWebFeed(feed)

						InitialFeedDownloader.download(url) { parsedFeed in
							self.refreshProgress.completeTask()

							if let parsedFeed = parsedFeed {
								account.update(feed, with: parsedFeed, {_ in
									BatchUpdate.shared.end()
									completion(.success(feed))
								})
							}
							
						}

					case .failure(let error):
						BatchUpdate.shared.end()
						self.refreshProgress.clear()
						completion(.failure(error))
					}
				}
								
			case .failure:
				BatchUpdate.shared.end()
				self.refreshProgress.clear()
				completion(.failure(AccountError.createErrorNotFound))
			}
			
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
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.removeWebFeed(feed, from: container) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				container.removeWebFeed(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
				completion(.failure(error))
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
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.createWebFeed(url: feed.url, editedName: feed.editedName, container: container) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let externalID):
				feed.externalID = externalID
				container.addWebFeed(feed)
				completion(.success(()))
			case .failure(let error):
				self.processAccountError(account, error)
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
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		accountZone.removeFolder(folder) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				account.removeFolder(folder)
				completion(.success(()))
			case .failure(let error):
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

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		}
		database.insertStatuses(syncStatuses)

		database.selectPendingCount { result in
			if let count = try? result.get(), count > 100 {
				self.sendArticleStatus(for: account) { _ in }
			}
		}

		return try? account.update(articles, statusKey: statusKey, flag: flag)
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
		
		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, refreshProgress: refreshProgress)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account,
															 database: database,
															 articlesZone: articlesZone,
															 refreshProgress: refreshProgress)
		
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
			zones.forEach { zone in
				zone.subscribeToZoneChanges()
			}
		}
		
	}
	
	func accountWillBeDeleted(_ account: Account) {
		zones.forEach { zone in
			zone.resetChangeToken()
		}
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
		refreshArticleStatus(for: account) { result in
			switch result {
			case .success:

				self.refreshProgress.completeTask()
				self.accountZone.fetchChangesInZone() { result in
					switch result {
					case .success:

						self.refreshProgress.completeTask()
						self.sendArticleStatus(for: account) { result in
							switch result {
							case .success:
								self.refreshProgress.completeTask()
								completion(.success(()))
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
				
				let webFeeds = account.flattenedWebFeeds()
				self.refreshProgress.addToNumberOfTasksAndRemaining(webFeeds.count - intialWebFeedsCount)

				self.refreshProgress.completeTask()
				self.sendArticleStatus(for: account) { result in
					switch result {
					case .success:
						
						self.refreshProgress.completeTask()
						self.refreshArticleStatus(for: account) { result in
							switch result {
							case .success:

								self.refreshProgress.completeTask()

								self.refresher.refreshFeeds(webFeeds) {
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
				
			case .failure(let error):
				fail(error)
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
	
}

extension CloudKitAccountDelegate: LocalAccountRefresherDelegate {
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, didProcess newAndUpdatedArticles: NewAndUpdatedArticles, completion: @escaping () -> Void) {
		if let newArticles = newAndUpdatedArticles.newArticles {
			articlesZone.sendNewArticles(newArticles) { _ in
				completion()
			}
		} else {
			completion()
		}
	}

	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: WebFeed) {
		refreshProgress.completeTask()
	}
	
	func localAccountRefresherDidFinish(_ refresher: LocalAccountRefresher) {
		refreshProgress.clear()
	}
	
}
