//
//  CloudKitAppDelegate.swift
//  Account
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import os.log
import SyncDatabase
import RSCore
import RSParser
import Articles
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
	
	private let refresher = LocalAccountRefresher()

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
		refreshAll(for: account, downloadFeeds: true, completion: completion)
	}

	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		os_log(.debug, log: log, "Sending article statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				guard syncStatuses.count > 0 else {
					completion(.success(()))
					return
				}
				
				let starredArticleIDs = syncStatuses.filter({ $0.key == .starred && $0.flag == true }).map({ $0.articleID })
				account.fetchArticlesAsync(.articleIDs(Set(starredArticleIDs))) { result in
					
					func processWithArticles(_ starredArticles: Set<Article>) {
						
						self.articlesZone.sendArticleStatus(syncStatuses, starredArticles: starredArticles) { result in
							switch result {
							case .success:
								self.database.deleteSelectedForProcessing(syncStatuses.map({ $0.articleID }) )
								os_log(.debug, log: self.log, "Done sending article statuses.")
								completion(.success(()))
							case .failure(let error):
								self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID }) )
								completion(.failure(error))
							}
						}
						
					}

					switch result {
					case .success(let starredArticles):
						processWithArticles(starredArticles)
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
		
		articlesZone.fetchChangesInZone() { result in
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
		
		accountZone.importOPML(rootExternalID: rootExternalID, items: normalizedItems, completion: completion)
	}
	
	func createWebFeed(for account: Account, url urlString: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(3)
		FeedFinder.find(url: url) { result in
			
			self.refreshProgress.completeTask()
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers), let url = URL(string: bestFeedSpecifier.urlString) else {
					self.refreshProgress.completeTask()
					completion(.failure(AccountError.createErrorNotFound))
					return
				}
				
				if account.hasWebFeed(withURL: bestFeedSpecifier.urlString) {
					self.refreshProgress.completeTask()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				self.accountZone.createWebFeed(url: bestFeedSpecifier.urlString, editedName: name, container: container) { result in

					self.refreshProgress.completeTask()
					switch result {
					case .success(let externalID):
						
						let feed = account.createWebFeed(with: nil, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
						feed.editedName = name
						feed.externalID = externalID
						container.addWebFeed(feed)

						InitialFeedDownloader.download(url) { parsedFeed in
							self.refreshProgress.completeTask()

							if let parsedFeed = parsedFeed {
								account.update(feed, with: parsedFeed, {_ in
									completion(.success(feed))
								})
							}
							
						}

					case .failure(let error):
						completion(.failure(error))
					}
				}
								
			case .failure:
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
		accountZone.delegate = CloudKitAcountZoneDelegate(account: account, refreshProgress: refreshProgress)
		articlesZone.delegate = CloudKitArticlesZoneDelegate(account: account, database: database, articlesZone: articlesZone)
		
		if account.externalID == nil {
			accountZone.findOrCreateAccount() { result in
				switch result {
				case .success(let externalID):
					account.externalID = externalID
					self.refreshAll(for: account, downloadFeeds: false) { result in
						if case .failure(let error) = result {
							os_log(.error, log: self.log, "Error while doing intial refresh: %@", error.localizedDescription)
						}
					}
				case .failure(let error):
					os_log(.error, log: self.log, "Error adding account container: %@", error.localizedDescription)
				}
			}
		}
		
		zones.forEach { zone in
			zone.subscribe()
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
	
	func refreshAll(for account: Account, downloadFeeds: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		
		let intialWebFeedsCount = downloadFeeds ? account.flattenedWebFeeds().count : 0
		refreshProgress.addToNumberOfTasksAndRemaining(3 + intialWebFeedsCount)

		BatchUpdate.shared.start()
		accountZone.fetchChangesInZone() { result in
			BatchUpdate.shared.end()
			switch result {
			case .success:
				
				let webFeeds = account.flattenedWebFeeds()
				if downloadFeeds {
					self.refreshProgress.addToNumberOfTasksAndRemaining(webFeeds.count - intialWebFeedsCount)
				}

				self.refreshProgress.completeTask()
				self.sendArticleStatus(for: account) { result in
					switch result {
					case .success:
						
						self.refreshProgress.completeTask()
						self.refreshArticleStatus(for: account) { result in
							switch result {
							case .success:

								self.refreshProgress.completeTask()

								guard downloadFeeds else {
									completion(.success(()))
									return
								}
								
								self.refresher.refreshFeeds(webFeeds, feedCompletionBlock: { _ in self.refreshProgress.completeTask() }) {
									account.metadata.lastArticleFetchEndTime = Date()
									self.refreshProgress.clear()
									completion(.success(()))
								}

							case .failure(let error):
								completion(.failure(error))
							}
						}
						
					case .failure(let error):
						completion(.failure(error))
					}

				}
				
			case .failure(let error):
				self.refreshProgress.clear()
				BatchUpdate.shared.end()
				completion(.failure(error))
			}
		}
	}
	
}
