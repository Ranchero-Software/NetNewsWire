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
import RSWeb
import SyncDatabase
import Database
import Core
import CloudKitExtras

class CloudKitSendStatusOperation: MainThreadOperation {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
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

	@MainActor func run() {
		os_log(.debug, log: log, "Sending article statuses...")

		if showProgress {

			Task { @MainActor in

				do {
					let count = (try await self.database.selectPendingCount()) ?? 0
					let ticks = count / self.blockSize
					self.refreshProgress?.addToNumberOfTasksAndRemaining(ticks)
					self.selectForProcessing()
				} catch {
					os_log(.error, log: self.log, "Send status count pending error: %@.", error.localizedDescription)
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

			MainActor.assumeIsolated {
				switch result {
				case .success(let syncStatuses):

					@MainActor func stopProcessing() {
						if self.showProgress {
							self.refreshProgress?.completeTask()
						}
						os_log(.debug, log: self.log, "Done sending article statuses.")
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
					os_log(.error, log: self.log, "Send status error: %@.", databaseError.localizedDescription)
					self.operationDelegate?.cancelOperation(self)
				}
			}
		}
	}
	
	@MainActor func processStatuses(_ syncStatuses: [SyncStatus], completion: @escaping (Bool) -> Void) {
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
				
				@Sendable func done(_ stop: Bool) {
					// Don't clear the last one since we might have had additional ticks added
					if self.showProgress && self.refreshProgress?.numberRemaining ?? 0 > 1 {
						self.refreshProgress?.completeTask()
					}
					os_log(.debug, log: self.log, "Done sending article status block...")
					completion(stop)
				}
				
				// If this happens, we have somehow gotten into a state where we have new status records
				// but the articles didn't come back in the fetch.  We need to clean up those sync records
				// and stop processing.
				if statusUpdates.isEmpty {
					Task { @MainActor in
						try? await self.database.deleteSelectedForProcessing(articleIDs)
						done(true)
					}
				} else {
					
					Task { @MainActor in
						articlesZone.modifyArticles(statusUpdates) { result in
							Task { @MainActor in
								switch result {
								case .success:
									try? await self.database.deleteSelectedForProcessing(statusUpdates.map({ $0.articleID }))
									done(false)
								case .failure(let error):
									try? await self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID }))
									self.processAccountError(account, error)
									os_log(.error, log: self.log, "Send article status modify articles error: %@.", error.localizedDescription)
									completion(true)
								}
							}
						}
					}
				}
			}

			switch result {
			case .success(let articles):
				processWithArticles(articles)
			case .failure(let databaseError):
				Task { @MainActor in
					try? await self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID }))
					os_log(.error, log: self.log, "Send article status fetch articles error: %@.", databaseError.localizedDescription)
					completion(true)
				}
			}
		}
	}

	@MainActor func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeeds(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolder(folder)
			}
		}
	}

}
