//
//  CloudKitSendStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import os.log
import RSCore
import RSWeb
import SyncDatabase

class CloudKitSendStatusOperation: MainThreadOperation {
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitSendStatusOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var account: Account?
	private weak var articlesZone: CloudKitArticlesZone?
	private weak var refreshProgress: DownloadProgress?
	private var showProgress: Bool
	private var database: SyncDatabase

	init(account: Account, articlesZone: CloudKitArticlesZone, refreshProgress: DownloadProgress, showProgress: Bool, database: SyncDatabase) {
		self.account = account
		self.articlesZone = articlesZone
		self.refreshProgress = refreshProgress
		self.showProgress = showProgress
		self.database = database
	}
	
	func run() {
		os_log(.debug, log: log, "Sending article statuses...")

		database.selectForProcessing { result in

			func processStatuses(_ syncStatuses: [SyncStatus]) {
				guard syncStatuses.count > 0 else {
					os_log(.debug, log: self.log, "Done sending article statuses.")
					self.operationDelegate?.operationDidComplete(self)
					return
				}

				let group = DispatchGroup()
				let syncStatusChunks = syncStatuses.chunked(into: 300)
				
				if self.showProgress {
					self.refreshProgress?.addToNumberOfTasksAndRemaining(syncStatusChunks.count)
				}
				
				for syncStatusChunk in syncStatusChunks {
					group.enter()
					self.sendArticleStatusChunk(syncStatuses: syncStatusChunk) {
						group.leave()
					}
				}
				
				group.notify(queue: DispatchQueue.global(qos: .background)) {
					os_log(.debug, log: self.log, "Done sending article statuses.")
					DispatchQueue.main.async {
						self.operationDelegate?.operationDidComplete(self)
					}
				}
				
			}

			switch result {
			case .success(let syncStatuses):
				processStatuses(syncStatuses)
			case .failure(let databaseError):
				os_log(.error, log: self.log, "Send status error: %@.", databaseError.localizedDescription)
				self.operationDelegate?.cancelOperation(self)
			}
		}
		
	}
	
	func sendArticleStatusChunk(syncStatuses: [SyncStatus], completion: @escaping () -> Void) {
		guard let account = account, let articlesZone = articlesZone else {
			completion()
			return
		}
		
		let articleIDs = syncStatuses.map({ $0.articleID })
		account.fetchArticlesAsync(.articleIDs(Set(articleIDs))) { result in
			
			func processWithArticles(_ articles: Set<Article>) {
				
				let syncStatusesDict = Dictionary(grouping: syncStatuses, by: { $0.articleID })
				let articlesDict = articles.reduce(into: [String: Article]()) { result, article in
					result[article.articleID] = article
				}
				let statusUpdates = syncStatusesDict.map { (key, value) in
					return CloudKitArticleStatusUpdate(articleID: key, statuses: value, article: articlesDict[key])
				}
				
				articlesZone.modifyArticles(statusUpdates) { result in
					switch result {
					case .success:
						self.database.deleteSelectedForProcessing(syncStatuses.map({ $0.articleID })) { _ in
							if self.showProgress {
								self.refreshProgress?.completeTask()
							}
							os_log(.debug, log: self.log, "Done sending article status block...")
							completion()
						}
					case .failure(let error):
						self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID })) { _ in
							self.processAccountError(account, error)
							os_log(.error, log: self.log, "Send article status modify articles error: %@.", error.localizedDescription)
							completion()
						}
					}
				}
				
			}

			switch result {
			case .success(let articles):
				processWithArticles(articles)
			case .failure(let databaseError):
				self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID })) { _ in
					os_log(.error, log: self.log, "Send article status fetch articles error: %@.", databaseError.localizedDescription)
					completion()
				}
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
