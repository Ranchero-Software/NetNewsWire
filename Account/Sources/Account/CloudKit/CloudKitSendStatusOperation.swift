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

		Task { @MainActor in
			logger.debug("Sending article statuses...")

			if showProgress {
				do {
					let count = try await database.selectPendingCount()
					let ticks = count / self.blockSize
					self.refreshProgress?.addToNumberOfTasksAndRemaining(ticks)
					self.selectForProcessing()
				} catch {
					self.logger.error("Send status count pending error: \(error.localizedDescription, privacy: .public)")
					self.operationDelegate?.cancelOperation(self)
				}
			} else {
				selectForProcessing()
			}
		}
	}
}

private extension CloudKitSendStatusOperation {
	
	func selectForProcessing() {

		@MainActor func stopProcessing() {
			if self.showProgress {
				self.refreshProgress?.completeTask()
			}
			self.logger.debug("Done sending article statuses.")
			self.operationDelegate?.operationDidComplete(self)
		}

		Task { @MainActor in
			do {
				let syncStatuses = try await database.selectForProcessing(limit: blockSize)
				guard syncStatuses.count > 0 else {
					stopProcessing()
					return
				}

				self.processStatuses(Array(syncStatuses)) { stop in
					if stop {
						stopProcessing()
					} else {
						self.selectForProcessing()
					}
				}
			} catch {
				self.logger.error("Send status error: \(error.localizedDescription, privacy: .public)")
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
			
            @MainActor func processWithArticles(_ articles: Set<Article>) {
				
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
				// but the articles didn't come back in the fetch. We need to clean up those sync records
				// and stop processing.
				if statusUpdates.isEmpty {
					Task { @MainActor in
						try? await self.database.deleteSelectedForProcessing(articleIDs)
						done(true)
					}
					return
				} else {
					articlesZone.modifyArticles(statusUpdates) { result in
						Task { @MainActor in
							switch result {
							case .success:
								try? await self.database.deleteSelectedForProcessing(statusUpdates.map({ $0.articleID }))
								done(false)
							case .failure(let error):
								try? await self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID }))
								self.processAccountError(account, error)
								self.logger.error("Send article status modify articles error: \(error.localizedDescription, privacy: .public)")
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
				Task { @MainActor in
					try? await self.database.resetSelectedForProcessing(syncStatuses.map({ $0.articleID }))
					self.logger.error("Send article status fetch articles error: \(databaseError.localizedDescription, privacy: .public)")
					completion(true)
				}
			}
		}
	}
	
	func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeeds(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolder(folder)
			}
		}
	}

}
