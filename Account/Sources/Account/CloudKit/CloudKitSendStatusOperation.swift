//
//  CloudKitSendStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSCore
import RSWeb
import SyncDatabase

class CloudKitSendStatusOperation: MainThreadOperation, Logging {
	
	private let blockSize = 150
	
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
        logger.debug("Sending article statuses...")
		
		if showProgress {
			
			database.selectPendingCount() { result in
				switch result {
				case .success(let count):
					let ticks = count / self.blockSize
					self.refreshProgress?.addToNumberOfTasksAndRemaining(ticks)
					self.selectForProcessing()
				case .failure(let databaseError):
                    self.logger.error("Send status count pending error: \(databaseError.localizedDescription)")
					self.operationDelegate?.cancelOperation(self)
				}
			}
			
		} else {
			
			selectForProcessing()
			
		}
		
	}
	
}

private extension CloudKitSendStatusOperation {
	
	func selectForProcessing() {
		database.selectForProcessing(limit: blockSize) { result in
			switch result {
			case .success(let syncStatuses):
				
				func stopProcessing() {
					if self.showProgress {
						self.refreshProgress?.completeTask()
					}
                    self.logger.debug("Done sending article statuses.")
					self.operationDelegate?.operationDidComplete(self)
				}
				
				guard syncStatuses.count > 0 else {
					stopProcessing()
					return
				}
				
				self.processStatuses(syncStatuses) { stop in
					if stop {
						stopProcessing()
					} else {
						self.selectForProcessing()
					}
				}
				
			case .failure(let databaseError):
                self.logger.error("Send status error: \(databaseError.localizedDescription)")
				self.operationDelegate?.cancelOperation(self)
			}
		}
	}
	
	func processStatuses(_ syncStatuses: [SyncStatus], completion: @escaping (Bool) -> Void) {
		guard let account = account, let articlesZone = articlesZone else {
			completion(true)
			return
		}
		
		let articleIDs = syncStatuses.map({ $0.articleID })
		account.fetchArticlesAsync(.articleIDs(Set(articleIDs))) { result in
			
			func processWithArticles(_ articles: Set<Article>) {
				
				let syncStatusesDict = Dictionary(grouping: syncStatuses, by: { $0.articleID })
				let articlesDict = articles.reduce(into: [String: Article]()) { result, article in
					result[article.articleID] = article
				}
				let statusUpdates = syncStatusesDict.compactMap { (key, value) in
					return CloudKitArticleStatusUpdate(articleID: key, statuses: value, article: articlesDict[key])
				}
				
				func done(_ stop: Bool) {
					// Don't clear the last one since we might have had additional ticks added
					if self.showProgress && self.refreshProgress?.numberRemaining ?? 0 > 1 {
						self.refreshProgress?.completeTask()
					}
                    self.logger.debug("Done sending article status block...")
					completion(stop)
				}
				
				// If this happens, we have somehow gotten into a state where we have new status records
				// but the articles didn't come back in the fetch.  We need to clean up those sync records
				// and stop processing.
				if statusUpdates.isEmpty {
					self.database.deleteSelectedForProcessing(articleIDs) { _ in
						done(true)
						return
					}
				} else {
					articlesZone.modifyArticles(statusUpdates) { result in
						switch result {
						case .success:
							self.database.deleteSelectedForProcessing(statusUpdates.map({ $0.articleID })) { _ in
								done(false)
							}
						case .failure(let error):
							self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID })) { _ in
								self.processAccountError(account, error)
                                self.logger.error("Send article status modify articles error: \(error.localizedDescription)")
								completion(true)
							}
						}
					}
				}
				
			}

			switch result {
			case .success(let articles):
				processWithArticles(articles)
			case .failure(let databaseError):
				self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID })) { _ in
                    self.logger.error("Send article status fetch articles error: \(databaseError.localizedDescription)")
					completion(true)
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
