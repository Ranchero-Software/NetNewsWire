//
//  CloudKitSendStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import os
import RSCore
import RSWeb
import SyncDatabase
import CloudKitSync
import ActivityLog

final class CloudKitSendStatusOperation: MainThreadOperation, @unchecked Sendable {
	private let blockSize = 150
	private weak var account: Account?
	private weak var articlesZone: CloudKitArticlesZone?
	private let accountID: String
	private var syncDatabase: SyncDatabase
	private let syncArticleContentForUnreadArticles: @Sendable () -> Bool
	private static let logger = cloudKitLogger
	let syncErrorHandler: CloudKitSyncErrorHandler?

	/// Number of statuses successfully sent during this run. Read after the
	/// operation completes.
	private(set) var sentCount = 0

	init(account: Account, articlesZone: CloudKitArticlesZone, database: SyncDatabase, syncArticleContentForUnreadArticles: @escaping @Sendable () -> Bool, syncErrorHandler: CloudKitSyncErrorHandler?) {
		self.account = account
		self.accountID = account.accountID
		self.articlesZone = articlesZone
		self.syncDatabase = database
		self.syncArticleContentForUnreadArticles = syncArticleContentForUnreadArticles
		self.syncErrorHandler = syncErrorHandler
		super.init(name: "CloudKitSendStatusOperation")
	}

	@MainActor override func run() {
		Self.logger.debug("iCloud: Sending article statuses")

		let activityLog = ActivityLog.shared
		let taskNumber = activityLog.nextTaskNumberString()
		let activityID = activityLog.createActivity(owner: .account(accountID: accountID, displayName: account?.nameForDisplay ?? accountID), kind: .sendArticleStatuses, detail: "Sending article statuses \(taskNumber)")
		activityLog.didStart(id: activityID)

		Task { @MainActor in
			do {
				let result = try await selectForProcessing()
				self.sentCount = result.sent
				Self.logger.debug("iCloud: Finished sending article statuses")
				if isCanceled {
					activityLog.didFail(id: activityID, error: CloudKitAccountDelegateError.unknown)
				} else if result.sent == 0 {
					activityLog.didComplete(id: activityID, message: "No statuses to send", durationIsSignificant: false)
				} else {
					var message = "\(result.sent) status\(result.sent == 1 ? "" : "es") sent"
					if result.withContent > 0 {
						message += " (\(result.withContent) with content)"
					}
					activityLog.didComplete(id: activityID, message: message)
				}
			} catch {
				Self.logger.debug("iCloud: Send status error: \(error.localizedDescription)")
				activityLog.didFail(id: activityID, error: error)
			}
			didComplete()
		}
	}
}

@MainActor private extension CloudKitSendStatusOperation {

	typealias SendResult = (sent: Int, withContent: Int)

	/// Returns the total number of statuses sent and the subset whose article content was also uploaded.
	func selectForProcessing() async throws -> SendResult {
		guard let syncStatuses = await syncDatabase.selectForProcessing(limit: blockSize),
			  !syncStatuses.isEmpty else {
			return (0, 0)
		}

		guard let batch = try await processStatuses(Array(syncStatuses)) else {
			return (0, 0)
		}

		let rest = try await selectForProcessing()
		return (batch.sent + rest.sent, batch.withContent + rest.withContent)
	}

	/// Returns the batch's send counts, or nil if processing should stop
	/// (account/zone gone, or no usable articles for the batch).
	func processStatuses(_ syncStatuses: [SyncStatus]) async throws -> SendResult? {
		guard let account, let articlesZone else {
			return nil
		}

		let articleIDs = syncStatuses.map({ $0.articleID })
		let articles = await account.fetchArticlesAsync(.articleIDs(Set(articleIDs)))

		let syncStatusesDict = Dictionary(grouping: syncStatuses, by: { $0.articleID })
		let articlesDict = articles.reduce(into: [String: Article]()) { result, article in
			result[article.articleID] = article
		}
		let statusUpdates = syncStatusesDict.compactMap { (key, value) in
			CloudKitArticleStatusUpdate(articleID: key, statuses: value, article: articlesDict[key], syncArticleContentForUnreadArticles: self.syncArticleContentForUnreadArticles)
		}

		// We somehow have new status records but the articles didn't come back
		// in the fetch. Clean up those sync records and stop processing.
		if statusUpdates.isEmpty {
			await syncDatabase.deleteSelectedForProcessing(Set(articleIDs))
			return nil
		}

		do {
			let withContent = try await account.logActivity(
				kind: .sendArticleStatuses,
				detail: ActivityLog.shared.nextTaskNumberString(),
				successMessage: { "\(statusUpdates.count) status\(statusUpdates.count == 1 ? "" : "es") sent\($0 > 0 ? " (\($0) with content)" : "")" },
				{
					try await articlesZone.modifyArticles(statusUpdates)
				}
			)
			await syncDatabase.deleteSelectedForProcessing(Set(statusUpdates.map({ $0.articleID })))
			return (statusUpdates.count, withContent)
		} catch {
			await syncDatabase.resetSelectedForProcessing(Set(syncStatuses.map({ $0.articleID })))
			syncErrorHandler?(error, "Sending article status", #fileID, #function, #line)
			Self.logger.error("iCloud: Send article status modify articles error: \(error.localizedDescription)")
			throw error
		}
	}

}
