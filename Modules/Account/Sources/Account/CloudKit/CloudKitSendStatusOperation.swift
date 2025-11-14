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
import CloudKitSync

final class CloudKitSendStatusOperation: MainThreadOperation, @unchecked Sendable {
	private let blockSize = 150
	private weak var account: Account?
	private weak var articlesZone: CloudKitArticlesZone?
	private weak var refreshProgress: DownloadProgress?
	private var showProgress: Bool
	private var syncDatabase: SyncDatabase
	private static let logger = cloudKitLogger

	init(account: Account, articlesZone: CloudKitArticlesZone, refreshProgress: DownloadProgress, showProgress: Bool, database: SyncDatabase) {
		self.account = account
		self.articlesZone = articlesZone
		self.refreshProgress = refreshProgress
		self.showProgress = showProgress
		self.syncDatabase = database
		super.init(name: "CloudKitSendStatusOperation")
	}

	@MainActor override func run() {
		Self.logger.debug("iCloud: Sending article statuses")

		if showProgress {
			Task { @MainActor in
				do {
					let count = (try await syncDatabase.selectPendingCount()) ?? 0
					let ticks = count / blockSize
					refreshProgress?.addToNumberOfTasksAndRemaining(ticks)
					selectForProcessing()
				} catch {
					Self.logger.debug("iCloud: Send status count pending error: \(error.localizedDescription)")
					didComplete()
				}
			}
		} else {
			selectForProcessing()
		}
	}
}

private extension CloudKitSendStatusOperation {

	func selectForProcessing() {
		Task { @MainActor in

			@MainActor func stopProcessing() {
				if self.showProgress {
					self.refreshProgress?.completeTask()
				}
				Self.logger.debug("iCloud: Finished sending article statuses")
				didComplete()
			}

			do {
				guard let syncStatuses = try await self.syncDatabase.selectForProcessing(limit: blockSize), !syncStatuses.isEmpty else {
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
				Self.logger.debug("iCloud: Send status error: \(error.localizedDescription)")
				didComplete()
			}
		}
	}

	@MainActor func processStatuses(_ syncStatuses: [SyncStatus], completion: @escaping (Bool) -> Void) {
		guard let account, let articlesZone else {
			completion(true)
			return
		}

		let articleIDs = syncStatuses.map({ $0.articleID })
		account.fetchArticlesAsync(.articleIDs(Set(articleIDs))) { result in

			func processWithArticles(_ articles: Set<Article>) {
				Task { @MainActor in

					let syncStatusesDict = Dictionary(grouping: syncStatuses, by: { $0.articleID })
					let articlesDict = articles.reduce(into: [String: Article]()) { result, article in
						result[article.articleID] = article
					}
					let statusUpdates = syncStatusesDict.compactMap { (key, value) in
						return CloudKitArticleStatusUpdate(articleID: key, statuses: value, article: articlesDict[key])
					}

					func done(_ stop: Bool) {
						if self.showProgress {
							self.refreshProgress?.completeTask()
						}
						Self.logger.debug("iCloud: Finished sending article status block")
						completion(stop)
					}

					// If this happens, we have somehow gotten into a state where we have new status records
					// but the articles didn't come back in the fetch.  We need to clean up those sync records
					// and stop processing.
					if statusUpdates.isEmpty {
						try? await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDs))
						done(true)
						return
					} else {
						do {
							try await articlesZone.modifyArticles(statusUpdates)
							try? await self.syncDatabase.deleteSelectedForProcessing(Set(statusUpdates.map({ $0.articleID })))
							done(false)
						} catch {
							try? await self.syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map({ $0.articleID })))
							self.processAccountError(account, error)
							Self.logger.error("iCloud: Send article status modify articles error: \(error.localizedDescription)")
							completion(true)
						}
					}
				}
			}

			switch result {
			case .success(let articles):
				processWithArticles(articles)
			case .failure(let databaseError):
				Task { @MainActor in
					try? await self.syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map({ $0.articleID })))
					Self.logger.error("iCloud: Send article status fetch articles error: \(databaseError.localizedDescription)")
					completion(true)
				}
			}
		}
	}

	@MainActor func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeedsFromTreeAtTopLevel(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolderFromTree(folder)
			}
		}
	}
}
