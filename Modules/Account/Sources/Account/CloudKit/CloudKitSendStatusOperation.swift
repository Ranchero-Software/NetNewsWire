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
	private let localProgress = DownloadProgress(numberOfTasks: 0)
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

		if showProgress {
			refreshProgress.addChild(self.localProgress)
		}
	}

	@MainActor override func run() {
		Self.logger.debug("iCloud: Sending article statuses")

		Task { @MainActor in
			defer {
				localProgress.completeAll()
				didComplete()
			}

			do {
				if showProgress {
					let count = (try await syncDatabase.selectPendingCount()) ?? 0
					let ticks = count / blockSize
					localProgress.addTasks(ticks)
				}

				await selectForProcessing()
				Self.logger.debug("iCloud: Finished sending article statuses")
			} catch {
				Self.logger.debug("iCloud: Send status error: \(error.localizedDescription)")
			}
		}
	}
}

@MainActor private extension CloudKitSendStatusOperation {

	func selectForProcessing() async {
		defer {
			if showProgress {
				localProgress.completeTask()
			}
		}

		do {
			guard let syncStatuses = try await syncDatabase.selectForProcessing(limit: blockSize),
				  !syncStatuses.isEmpty else {
				return
			}

			let stopProcessing = await processStatuses(Array(syncStatuses))
			if stopProcessing {
				return
			}

			await selectForProcessing()
		} catch {
			Self.logger.debug("iCloud: Send status error: \(error.localizedDescription)")
		}
	}

	/// Returns true if processing should stop.
	func processStatuses(_ syncStatuses: [SyncStatus]) async -> Bool {
		guard let account, let articlesZone else {
			return true
		}

		let articleIDs = syncStatuses.map({ $0.articleID })
		let articles: Set<Article>

		do {
			articles = try await account.fetchArticlesAsync(.articleIDs(Set(articleIDs)))
		} catch {
			try? await syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map({ $0.articleID })))
			Self.logger.error("iCloud: Send article status fetch articles error: \(error.localizedDescription)")
			return true
		}

		let syncStatusesDict = Dictionary(grouping: syncStatuses, by: { $0.articleID })
		let articlesDict = articles.reduce(into: [String: Article]()) { result, article in
			result[article.articleID] = article
		}
		let statusUpdates = syncStatusesDict.compactMap { (key, value) in
			CloudKitArticleStatusUpdate(articleID: key, statuses: value, article: articlesDict[key])
		}


		// If this happens, we have somehow gotten into a state where we have new status records
		// but the articles didn't come back in the fetch. We need to clean up those sync records
		// and stop processing.
		if statusUpdates.isEmpty {
			try? await syncDatabase.deleteSelectedForProcessing(Set(articleIDs))
			return true
		} else {
			do {
				try await articlesZone.modifyArticles(statusUpdates)
				try? await syncDatabase.deleteSelectedForProcessing(Set(statusUpdates.map({ $0.articleID })))
				return false
			} catch {
				try? await syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map({ $0.articleID })))
				processAccountError(account, error)
				Self.logger.error("iCloud: Send article status modify articles error: \(error.localizedDescription)")
				return true
			}
		}
	}

	func processAccountError(_ account: Account, _ error: Error) {
		if case CloudKitZoneError.userDeletedZone = error {
			account.removeFeedsFromTreeAtTopLevel(account.topLevelFeeds)
			for folder in account.folders ?? Set<Folder>() {
				account.removeFolderFromTree(folder)
			}
		}
	}
}
