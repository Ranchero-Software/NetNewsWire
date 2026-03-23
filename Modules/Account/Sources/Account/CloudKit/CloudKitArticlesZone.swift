//
//  CloudKitArticlesZone.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSParser
import RSWeb
import CloudKit
import Articles
import SyncDatabase
import CloudKitSync

final class CloudKitArticlesZone: CloudKitZone {

	private static let logger = cloudKitLogger
	private static let staleStatusRecordInterval: TimeInterval = 183 * 24 * 60 * 60 // ~6 months
	private static let cleanUpLimit = 400

	struct StatusRecordInfo {
		let read: Bool
		let starred: Bool
		let creationDate: Date?

		init(record: CKRecord) {
			let readValue = record[CloudKitArticleStatus.Fields.read] as? String ?? "1"
			let starredValue = record[CloudKitArticleStatus.Fields.starred] as? String ?? "0"
			self.read = readValue != "0"
			self.starred = starredValue == "1"
			self.creationDate = record.creationDate
		}
	}

	struct StatusRecordScanResult {
		let total: Int
		let starred: Int
		let unread: Int
		let read: Int
		let stale: Int
		let statusByRecordID: [CKRecord.ID: StatusRecordInfo]
	}

	struct ArticleRecordScanResult {
		let total: Int
		let starred: Int
		let unread: Int
		let read: Int
		let orphaned: Int
		let contentRecordIDByStatusID: [CKRecord.ID: CKRecord.ID]
		let orphanedContentRecordIDs: [CKRecord.ID]
	}

	struct ScanCache {
		private static let maxAge: TimeInterval = 5 * 60

		let creationDate: Date
		let statusByRecordID: [CKRecord.ID: StatusRecordInfo]
		let contentRecordIDByStatusID: [CKRecord.ID: CKRecord.ID]
		let orphanedContentRecordIDs: [CKRecord.ID]

		var isValid: Bool {
			Date().timeIntervalSince(creationDate) < Self.maxAge
		}
	}

	var zoneID: CKRecordZone.ID

	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate?

	private var scanCache: ScanCache?

	struct CloudKitArticle: Sendable {
		static let recordType = "Article"
		struct Fields {
			static let articleStatus = "articleStatus"
			static let feedURL = "webFeedURL"
			static let uniqueID = "uniqueID"
			static let title = "title"
			static let contentHTML = "contentHTML"
			static let contentHTMLData = "contentHTMLData"
			static let contentText = "contentText"
			static let contentTextData = "contentTextData"
			static let url = "url"
			static let externalURL = "externalURL"
			static let summary = "summary"
			static let imageURL = "imageURL"
			static let datePublished = "datePublished"
			static let dateModified = "dateModified"
			static let parsedAuthors = "parsedAuthors"
		}
	}

	struct CloudKitArticleStatus: Sendable {
		static let recordType = "ArticleStatus"
		struct Fields {
			static let feedExternalID = "webFeedExternalID"
			static let read = "read"
			static let starred = "starred"
		}
	}

	let syncArticleContentForUnreadArticles: @Sendable () -> Bool

	init(container: CKContainer, syncArticleContentForUnreadArticles: @escaping @Sendable () -> Bool) {
		self.container = container
		self.database = container.privateCloudDatabase
		self.zoneID = CKRecordZone.ID(zoneName: "Articles", ownerName: CKCurrentUserDefaultName)
		self.syncArticleContentForUnreadArticles = syncArticleContentForUnreadArticles
	}

	@MainActor func refreshArticles() async throws {
		do {
			try await fetchChangesInZone()
		} catch {
			if case CloudKitZoneError.userDeletedZone = error {
				try await createZoneRecord()
				try await refreshArticles()
			} else {
				throw error
			}
		}
	}

	@MainActor func saveNewArticles(_ articles: Set<Article>) async throws {
		guard !articles.isEmpty else {
			return
		}

		var records = [CKRecord]()

		let syncUnreadContent = syncArticleContentForUnreadArticles()
		Self.logger.info("CloudKitArticlesZone: saveNewArticles syncUnreadContent: \(syncUnreadContent, privacy: .public)")

		for article in articles {
			if article.status.starred {
				records.append(makeStatusRecord(article))
				records.append(makeArticleRecord(article))
			} else if !article.status.read {
				records.append(makeStatusRecord(article))
				if syncUnreadContent {
					records.append(makeArticleRecord(article))
				} else {
					Self.logger.debug("CloudKitArticlesZone: saveNewArticles skipping content for unread article \(article.articleID, privacy: .public)")
				}
			}
		}

		let compressedRecords = await Task.detached(priority: .userInitiated) {
			self.compressArticleRecords(records)
		}.value
		try await save(compressedRecords)
	}

	func deleteArticles(_ feedExternalID: String) async throws {
		let predicate = NSPredicate(format: "webFeedExternalID = %@", feedExternalID)
		let ckQuery = CKQuery(recordType: CloudKitArticleStatus.recordType, predicate: predicate)
		try await delete(ckQuery: ckQuery)
	}

	@MainActor func modifyArticles(_ statusUpdates: [CloudKitArticleStatusUpdate]) async throws {
		guard !statusUpdates.isEmpty else {
			return
		}

		var modifyRecords = [CKRecord]()
		var newRecords = [CKRecord]()
		var deleteRecordIDs = [CKRecord.ID]()

		let syncUnreadContent = syncArticleContentForUnreadArticles()
		Self.logger.info("CloudKitArticlesZone: modifyArticles syncUnreadContent: \(syncUnreadContent, privacy: .public)")

		for statusUpdate in statusUpdates {
			switch statusUpdate.record {
			case .all:
				modifyRecords.append(self.makeStatusRecord(statusUpdate))
				modifyRecords.append(self.makeArticleRecord(statusUpdate.article!))
			case .new:
				newRecords.append(self.makeStatusRecord(statusUpdate))
				if statusUpdate.article!.status.starred || syncUnreadContent {
					newRecords.append(self.makeArticleRecord(statusUpdate.article!))
				} else {
					Self.logger.debug("CloudKitArticlesZone: modifyArticles skipping content for unread article \(statusUpdate.articleID, privacy: .public)")
				}
			case .delete:
				deleteRecordIDs.append(CKRecord.ID(recordName: self.statusID(statusUpdate.articleID), zoneID: zoneID))
			case .statusOnly:
				modifyRecords.append(self.makeStatusRecord(statusUpdate))
				deleteRecordIDs.append(CKRecord.ID(recordName: self.articleID(statusUpdate.articleID), zoneID: zoneID))
			}
		}

		let (compressedModifyRecords, compressedNewRecords) = await Task.detached(priority: .userInitiated) {
			let compressedModify = self.compressArticleRecords(modifyRecords)
			let compressedNew = self.compressArticleRecords(newRecords)
			return (compressedModify, compressedNew)
		}.value

		do {
			try await modify(recordsToSave: compressedModifyRecords, recordIDsToDelete: deleteRecordIDs)
			try await saveIfNew(compressedNewRecords)
		} catch {
			try await handleModifyArticlesError(error, statusUpdates: statusUpdates)
		}
	}

	/// Periodic cleanup path. Scans content records incrementally, stopping when
	/// the limit is hit. No `ScanCache` awareness — the periodic cleanup runs on
	/// launch before the user would open the stats window.
	func cleanUpRecords(account: Account, syncUnreadContent: Bool, dryRun: Bool, limit: Int = CloudKitArticlesZone.cleanUpLimit) async throws -> Int {
		guard let database else {
			return 0
		}

		Self.logger.info("CloudKitArticlesZone: cleanUpRecords: performing incremental scan")
		let statusByRecordID = try await fetchStatusRecordMap()

		var deleteRecordIDs = try await scanContentRecordsIncrementally(database: database, statusByRecordID: statusByRecordID, syncUnreadContent: syncUnreadContent, limit: limit)
		Self.logger.info("CloudKitArticlesZone: cleanUpRecords: \(deleteRecordIDs.count, privacy: .public) content records to delete")

		if deleteRecordIDs.count < limit {
			let statusIDs = try await staleStatusRecordIDsToDelete(from: statusByRecordID, account: account, limit: limit - deleteRecordIDs.count)
			Self.logger.info("CloudKitArticlesZone: cleanUpRecords: \(statusIDs.count, privacy: .public) status records to delete")
			deleteRecordIDs.append(contentsOf: statusIDs)
		}

		return try await deleteCleanUpRecords(deleteRecordIDs, dryRun: dryRun)
	}

	/// Cache-aware cleanup for the CloudKit Stats "Clean Up" button.
	/// Attempts to clean up everything — no limit. Uses `ScanCache` if valid,
	/// falling back to a full scan. Clears the cache after use.
	func cleanUpRecordsUsingCache(account: Account, syncUnreadContent: Bool, dryRun: Bool) async throws -> Int {
		guard database != nil else {
			return 0
		}

		let statusByRecordID: [CKRecord.ID: StatusRecordInfo]
		var deleteRecordIDs: [CKRecord.ID]

		if let cache = scanCache, cache.isValid {
			Self.logger.info("CloudKitArticlesZone: cleanUpRecordsUsingCache: using cached scan data")
			statusByRecordID = cache.statusByRecordID
			deleteRecordIDs = contentRecordIDsToDelete(contentRecordIDByStatusID: cache.contentRecordIDByStatusID, orphanedContentRecordIDs: cache.orphanedContentRecordIDs, statusByRecordID: statusByRecordID, syncUnreadContent: syncUnreadContent)
		} else {
			Self.logger.info("CloudKitArticlesZone: cleanUpRecordsUsingCache: no valid cache, performing full scan")
			statusByRecordID = try await fetchStatusRecordMap()
			let (contentRecordIDByStatusID, orphanedContentRecordIDs) = try await fetchAllContentRecordMappings()
			deleteRecordIDs = contentRecordIDsToDelete(contentRecordIDByStatusID: contentRecordIDByStatusID, orphanedContentRecordIDs: orphanedContentRecordIDs, statusByRecordID: statusByRecordID, syncUnreadContent: syncUnreadContent)
		}
		scanCache = nil

		Self.logger.info("CloudKitArticlesZone: cleanUpRecordsUsingCache: \(deleteRecordIDs.count, privacy: .public) content records to delete")

		let statusIDs = try await staleStatusRecordIDsToDelete(from: statusByRecordID, account: account)
		Self.logger.info("CloudKitArticlesZone: cleanUpRecordsUsingCache: \(statusIDs.count, privacy: .public) status records to delete")
		deleteRecordIDs.append(contentsOf: statusIDs)

		return try await deleteCleanUpRecords(deleteRecordIDs, dryRun: dryRun)
	}

	func fetchStats(account: Account, progress: @escaping CloudKitStatsProgressHandler) async throws -> CloudKitStats {

		func makeStats(_ statusScan: StatusRecordScanResult? = nil, _ articleScan: ArticleRecordScanResult? = nil) -> CloudKitStats {
			CloudKitStats(
				statusCount: statusScan?.total ?? 0,
				starredStatusCount: statusScan?.starred ?? 0,
				unreadStatusCount: statusScan?.unread ?? 0,
				readStatusCount: statusScan?.read ?? 0,
				staleStatusCount: statusScan?.stale ?? 0,
				articleCount: articleScan?.total ?? 0,
				starredArticleCount: articleScan?.starred ?? 0,
				unreadArticleCount: articleScan?.unread ?? 0,
				readArticleCount: articleScan?.read ?? 0,
				orphanedArticleCount: articleScan?.orphaned ?? 0
			)
		}

		// Phase 1: Scan all status records

		progress(makeStats())
		let statusScan = try await scanStatusRecords(account: account) { statusResult in
			progress(makeStats(statusResult))
		}

		// Phase 2: Scan all article content records

		try Task.checkCancellation()
		progress(makeStats(statusScan))

		let contentScan = try await scanArticleContentRecords(statusByRecordID: statusScan.statusByRecordID) { articleResult in
			progress(makeStats(statusScan, articleResult))
		}

		scanCache = ScanCache(
			creationDate: Date(),
			statusByRecordID: statusScan.statusByRecordID,
			contentRecordIDByStatusID: contentScan.contentRecordIDByStatusID,
			orphanedContentRecordIDs: contentScan.orphanedContentRecordIDs
		)

		return makeStats(statusScan, contentScan)
	}
}

private extension CloudKitArticlesZone {

	// MARK: - Record Cleanup Helpers

	/// Returns content record IDs to delete from pre-fetched scan data.
	/// Deletes orphaned records, read + unstarred records, and unread + unstarred
	/// records when syncUnreadContent is off.
	func contentRecordIDsToDelete(contentRecordIDByStatusID: [CKRecord.ID: CKRecord.ID], orphanedContentRecordIDs: [CKRecord.ID], statusByRecordID: [CKRecord.ID: StatusRecordInfo], syncUnreadContent: Bool, limit: Int = .max) -> [CKRecord.ID] {
		var deleteRecordIDs = [CKRecord.ID]()

		for recordID in orphanedContentRecordIDs {
			if deleteRecordIDs.count >= limit {
				break
			}
			deleteRecordIDs.append(recordID)
		}

		for (statusID, contentRecordID) in contentRecordIDByStatusID {
			if deleteRecordIDs.count >= limit {
				break
			}
			guard let statusInfo = statusByRecordID[statusID] else {
				// Status not found — content is orphaned.
				deleteRecordIDs.append(contentRecordID)
				continue
			}
			// Never delete content for starred articles.
			if statusInfo.starred {
				continue
			}
			// Delete content for read articles, and for unread articles
			// when unread content syncing is off.
			if statusInfo.read || !syncUnreadContent {
				deleteRecordIDs.append(contentRecordID)
			}
		}

		return deleteRecordIDs
	}

	/// Returns stale status record IDs from pre-fetched scan data: unstarred,
	/// older than 6 months, with no corresponding local article.
	func staleStatusRecordIDsToDelete(from statusByRecordID: [CKRecord.ID: StatusRecordInfo], account: Account, limit: Int = .max) async throws -> [CKRecord.ID] {
		let cutoffDate = Date(timeIntervalSinceNow: -Self.staleStatusRecordInterval)

		var staleCandidates = [(articleID: String, recordID: CKRecord.ID)]()
		for (recordID, statusInfo) in statusByRecordID {
			if !statusInfo.starred, let creationDate = statusInfo.creationDate, creationDate < cutoffDate {
				let baseID = String(recordID.recordName.dropFirst(2))
				staleCandidates.append((baseID, recordID))
			}
		}

		guard !staleCandidates.isEmpty else {
			return []
		}

		// Check stale candidates against local database.
		// Delete records with no corresponding local article.
		let candidateIDs = Set(staleCandidates.map { $0.articleID })
		let existingArticles = try await account.fetchArticlesAsync(.articleIDs(candidateIDs))
		let existingArticleIDs = Set(existingArticles.map { $0.articleID })

		var deleteRecordIDs = [CKRecord.ID]()
		for (articleID, recordID) in staleCandidates {
			if deleteRecordIDs.count >= limit {
				break
			}
			if !existingArticleIDs.contains(articleID) {
				deleteRecordIDs.append(recordID)
			}
		}

		return deleteRecordIDs
	}

	// MARK: - Fresh Scan Helpers

	/// Fetches all status records and builds a map of record ID to status info.
	/// Used by cleanup when no cached scan data is available.
	func fetchStatusRecordMap() async throws -> [CKRecord.ID: StatusRecordInfo] {
		Self.logger.info("CloudKitArticlesZone: fetchStatusRecordMap: querying all ArticleStatus records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let desiredKeys = [CloudKitArticleStatus.Fields.read, CloudKitArticleStatus.Fields.starred]
		let ckQuery = CKQuery(recordType: CloudKitArticleStatus.recordType, predicate: predicate)
		let records = try await query(ckQuery, desiredKeys: desiredKeys)
		Self.logger.info("CloudKitArticlesZone: fetchStatusRecordMap: fetched \(records.count, privacy: .public) records")

		var statusByRecordID = [CKRecord.ID: StatusRecordInfo]()
		for record in records {
			statusByRecordID[record.recordID] = StatusRecordInfo(record: record)
		}
		return statusByRecordID
	}

	/// Fetches all article content records and builds a mapping of status record IDs
	/// to content record IDs, plus a list of orphaned content record IDs.
	/// Used by the unlimited cache-miss path in cleanUpRecordsUsingCache.
	func fetchAllContentRecordMappings() async throws -> (contentRecordIDByStatusID: [CKRecord.ID: CKRecord.ID], orphanedContentRecordIDs: [CKRecord.ID]) {
		Self.logger.info("CloudKitArticlesZone: fetchAllContentRecordMappings: querying all Article records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)
		let records = try await query(ckQuery, desiredKeys: [CloudKitArticle.Fields.articleStatus])
		Self.logger.info("CloudKitArticlesZone: fetchAllContentRecordMappings: fetched \(records.count, privacy: .public) records")

		var contentRecordIDByStatusID = [CKRecord.ID: CKRecord.ID]()
		var orphanedContentRecordIDs = [CKRecord.ID]()
		for record in records {
			guard let reference = record[CloudKitArticle.Fields.articleStatus] as? CKRecord.Reference else {
				orphanedContentRecordIDs.append(record.recordID)
				continue
			}
			contentRecordIDByStatusID[reference.recordID] = record.recordID
		}
		return (contentRecordIDByStatusID, orphanedContentRecordIDs)
	}

	/// Scans content records incrementally, stopping when the limit is hit.
	/// Uses the modern async CKDatabase pagination API directly.
	func scanContentRecordsIncrementally(database: CKDatabase, statusByRecordID: [CKRecord.ID: StatusRecordInfo], syncUnreadContent: Bool, limit: Int) async throws -> [CKRecord.ID] {
		Self.logger.info("CloudKitArticlesZone: scanContentRecordsIncrementally: querying Article records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)

		var deleteRecordIDs = [CKRecord.ID]()

		var (matchResults, cursor) = try await database.records(
			matching: ckQuery, inZoneWith: zoneID,
			desiredKeys: [CloudKitArticle.Fields.articleStatus], resultsLimit: CKQueryOperation.maximumResults
		)
		processMatchResults(matchResults, statusByRecordID: statusByRecordID, syncUnreadContent: syncUnreadContent, limit: limit, into: &deleteRecordIDs)

		while let nextCursor = cursor, deleteRecordIDs.count < limit {
			(matchResults, cursor) = try await database.records(
				continuingMatchFrom: nextCursor,
				desiredKeys: [CloudKitArticle.Fields.articleStatus], resultsLimit: CKQueryOperation.maximumResults
			)
			processMatchResults(matchResults, statusByRecordID: statusByRecordID, syncUnreadContent: syncUnreadContent, limit: limit, into: &deleteRecordIDs)
		}

		Self.logger.info("CloudKitArticlesZone: scanContentRecordsIncrementally: found \(deleteRecordIDs.count, privacy: .public) records to delete")
		return deleteRecordIDs
	}

	/// Processes a page of match results from incremental content scanning,
	/// appending deletable record IDs to the output array.
	func processMatchResults(_ matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], statusByRecordID: [CKRecord.ID: StatusRecordInfo], syncUnreadContent: Bool, limit: Int, into deleteRecordIDs: inout [CKRecord.ID]) {
		for (_, result) in matchResults {
			if deleteRecordIDs.count >= limit {
				break
			}
			guard case .success(let record) = result else {
				continue
			}
			guard let reference = record[CloudKitArticle.Fields.articleStatus] as? CKRecord.Reference else {
				// No status reference — content is orphaned.
				deleteRecordIDs.append(record.recordID)
				continue
			}
			guard let statusInfo = statusByRecordID[reference.recordID] else {
				// Status not found — content is orphaned.
				deleteRecordIDs.append(record.recordID)
				continue
			}
			// Never delete content for starred articles.
			if statusInfo.starred {
				continue
			}
			// Delete content for read articles, or for unread articles
			// when unread content syncing is off.
			if statusInfo.read || !syncUnreadContent {
				deleteRecordIDs.append(record.recordID)
			}
		}
	}

	/// Shared tail for both cleanup entry points: log, dry-run check, delete.
	func deleteCleanUpRecords(_ deleteRecordIDs: [CKRecord.ID], dryRun: Bool) async throws -> Int {
		if deleteRecordIDs.isEmpty {
			Self.logger.info("CloudKitArticlesZone: cleanUpRecords: nothing to clean up")
			return 0
		}

		if dryRun {
			Self.logger.info("CloudKitArticlesZone: cleanUpRecords: DRY RUN — would delete \(deleteRecordIDs.count, privacy: .public) total records")
			return deleteRecordIDs.count
		}

		Self.logger.info("CloudKitArticlesZone: cleanUpRecords: deleting \(deleteRecordIDs.count, privacy: .public) total records")
		try await modify(recordsToSave: [], recordIDsToDelete: deleteRecordIDs)
		Self.logger.info("CloudKitArticlesZone: cleanUpRecords: deleted \(deleteRecordIDs.count, privacy: .public) records")
		return deleteRecordIDs.count
	}

	// MARK: - Stats Scanning

	func scanStatusRecords(account: Account, progress: @escaping @MainActor @Sendable (StatusRecordScanResult) async -> Void) async throws -> StatusRecordScanResult {

		let cutoffDate = Date(timeIntervalSinceNow: -Self.staleStatusRecordInterval)

		Self.logger.info("CloudKitArticlesZone: scanStatusRecords: querying all ArticleStatus records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let desiredKeys = [CloudKitArticleStatus.Fields.read, CloudKitArticleStatus.Fields.starred]
		let ckQuery = CKQuery(recordType: CloudKitArticleStatus.recordType, predicate: predicate)

		var totalCount = 0
		var starredCount = 0
		var unreadCount = 0
		var readCount = 0
		var pagesCompleted = 0
		var staleCandidateArticleIDs = [String]()
		var statusByRecordID = [CKRecord.ID: StatusRecordInfo]()

		try await queryPaginated(ckQuery, desiredKeys: desiredKeys) { pageRecords in
			try Task.checkCancellation()
			for record in pageRecords {
				let statusInfo = StatusRecordInfo(record: record)
				statusByRecordID[record.recordID] = statusInfo

				if statusInfo.starred {
					starredCount += 1
				}
				if statusInfo.read {
					readCount += 1
				} else {
					unreadCount += 1
				}

				if !statusInfo.starred, let creationDate = statusInfo.creationDate, creationDate < cutoffDate {
					let baseID = String(record.recordID.recordName.dropFirst(2))
					staleCandidateArticleIDs.append(baseID)
				}
			}
			totalCount += pageRecords.count
			pagesCompleted += 1
			await progress(StatusRecordScanResult(total: totalCount, starred: starredCount, unread: unreadCount, read: readCount, stale: 0, statusByRecordID: [:]))
		}

		Self.logger.info("CloudKitArticlesZone: scanStatusRecords: fetched \(totalCount, privacy: .public) ArticleStatus records in \(pagesCompleted, privacy: .public) pages")

		try Task.checkCancellation()

		var staleCount = 0
		if !staleCandidateArticleIDs.isEmpty {
			let existingArticles = try await account.fetchArticlesAsync(.articleIDs(Set(staleCandidateArticleIDs)))
			let existingArticleIDs = Set(existingArticles.map { $0.articleID })
			staleCount = staleCandidateArticleIDs.filter { !existingArticleIDs.contains($0) }.count
		}

		Self.logger.info("CloudKitArticlesZone: scanStatusRecords: final — total: \(totalCount, privacy: .public), starred: \(starredCount, privacy: .public), unread: \(unreadCount, privacy: .public), read: \(readCount, privacy: .public), stale: \(staleCount, privacy: .public)")
		return StatusRecordScanResult(total: totalCount, starred: starredCount, unread: unreadCount, read: readCount, stale: staleCount, statusByRecordID: statusByRecordID)
	}

	func scanArticleContentRecords(statusByRecordID: [CKRecord.ID: StatusRecordInfo], progress: @escaping @MainActor @Sendable (ArticleRecordScanResult) async -> Void) async throws -> ArticleRecordScanResult {
		guard database != nil else {
			Self.logger.info("CloudKitArticlesZone: scanArticleContentRecords: no database, returning 0")
			return ArticleRecordScanResult(total: 0, starred: 0, unread: 0, read: 0, orphaned: 0, contentRecordIDByStatusID: [:], orphanedContentRecordIDs: [])
		}

		Self.logger.info("CloudKitArticlesZone: scanArticleContentRecords: querying all Article records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)

		var totalCount = 0
		var starredCount = 0
		var unreadCount = 0
		var readCount = 0
		var orphanedCount = 0
		var contentRecordIDByStatusID = [CKRecord.ID: CKRecord.ID]()
		var orphanedContentRecordIDs = [CKRecord.ID]()

		try await queryPaginated(ckQuery, desiredKeys: [CloudKitArticle.Fields.articleStatus]) { pageRecords in
			try Task.checkCancellation()
			for record in pageRecords {
				guard let reference = record[CloudKitArticle.Fields.articleStatus] as? CKRecord.Reference else {
					orphanedCount += 1
					orphanedContentRecordIDs.append(record.recordID)
					continue
				}
				if let statusInfo = statusByRecordID[reference.recordID] {
					contentRecordIDByStatusID[reference.recordID] = record.recordID
					if statusInfo.starred {
						starredCount += 1
					}
					if statusInfo.read {
						readCount += 1
					} else {
						unreadCount += 1
					}
				} else {
					orphanedCount += 1
					orphanedContentRecordIDs.append(record.recordID)
				}
			}
			totalCount += pageRecords.count
			await progress(ArticleRecordScanResult(total: totalCount, starred: starredCount, unread: unreadCount, read: readCount, orphaned: orphanedCount, contentRecordIDByStatusID: [:], orphanedContentRecordIDs: []))
		}

		Self.logger.info("CloudKitArticlesZone: scanArticleContentRecords: final — total: \(totalCount, privacy: .public), starred: \(starredCount, privacy: .public), unread: \(unreadCount, privacy: .public), read: \(readCount, privacy: .public), orphaned: \(orphanedCount, privacy: .public)")
		return ArticleRecordScanResult(total: totalCount, starred: starredCount, unread: unreadCount, read: readCount, orphaned: orphanedCount, contentRecordIDByStatusID: contentRecordIDByStatusID, orphanedContentRecordIDs: orphanedContentRecordIDs)
	}

	func handleModifyArticlesError(_ error: Error, statusUpdates: [CloudKitArticleStatusUpdate]) async throws {
		if case CloudKitZoneError.userDeletedZone = error {
			try await createZoneRecord()
			try await modifyArticles(statusUpdates)
		} else {
			throw error
		}
	}

	func statusID(_ id: String) -> String {
		return "s|\(id)"
	}

	func articleID(_ id: String) -> String {
		return "a|\(id)"
	}

	@MainActor func makeStatusRecord(_ article: Article) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(article.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
		if let feedExternalID = article.feed?.externalID {
			record[CloudKitArticleStatus.Fields.feedExternalID] = feedExternalID
		}
		record[CloudKitArticleStatus.Fields.read] = article.status.read ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = article.status.starred ? "1" : "0"
		return record
	}

	@MainActor func makeStatusRecord(_ statusUpdate: CloudKitArticleStatusUpdate) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(statusUpdate.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)

		if let feedExternalID = statusUpdate.article?.feed?.externalID {
			record[CloudKitArticleStatus.Fields.feedExternalID] = feedExternalID
		}

		record[CloudKitArticleStatus.Fields.read] = statusUpdate.isRead ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = statusUpdate.isStarred ? "1" : "0"

		return record
	}

	@MainActor func makeArticleRecord(_ article: Article) -> CKRecord {
		let recordID = CKRecord.ID(recordName: articleID(article.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticle.recordType, recordID: recordID)

		let articleStatusRecordID = CKRecord.ID(recordName: statusID(article.articleID), zoneID: zoneID)
		record[CloudKitArticle.Fields.articleStatus] = CKRecord.Reference(recordID: articleStatusRecordID, action: .deleteSelf)
		record[CloudKitArticle.Fields.feedURL] = article.feed?.url
		record[CloudKitArticle.Fields.uniqueID] = article.uniqueID
		record[CloudKitArticle.Fields.title] = article.title
		record[CloudKitArticle.Fields.contentHTML] = article.contentHTML
		record[CloudKitArticle.Fields.contentText] = article.contentText
		record[CloudKitArticle.Fields.url] = article.rawLink
		record[CloudKitArticle.Fields.externalURL] = article.rawExternalLink
		record[CloudKitArticle.Fields.summary] = article.summary
		record[CloudKitArticle.Fields.imageURL] = article.rawImageLink
		record[CloudKitArticle.Fields.datePublished] = article.datePublished
		record[CloudKitArticle.Fields.dateModified] = article.dateModified

		let encoder = JSONEncoder()
		var parsedAuthors = [String]()

		if let authors = article.authors, !authors.isEmpty {
			for author in authors {
				let parsedAuthor = ParsedAuthor(name: author.name,
												url: author.url,
												avatarURL: author.avatarURL,
												emailAddress: author.emailAddress)
				if let data = try? encoder.encode(parsedAuthor), let encodedParsedAuthor = String(data: data, encoding: .utf8) {
					parsedAuthors.append(encodedParsedAuthor)
				}
			}
			record[CloudKitArticle.Fields.parsedAuthors] = parsedAuthors
		}

		return record
	}

	nonisolated func compressArticleRecords(_ records: [CKRecord]) -> [CKRecord] {
		var result = [CKRecord]()

		for record in records {

			if record.recordType == CloudKitArticle.recordType {

				if let contentHTML = record[CloudKitArticle.Fields.contentHTML] as? String {
					let data = Data(contentHTML.utf8) as NSData
					if let compressedData = try? data.compressed(using: .lzfse) {
						record[CloudKitArticle.Fields.contentHTMLData] = compressedData as Data
						record[CloudKitArticle.Fields.contentHTML] = nil
					}
				}

				if let contentText = record[CloudKitArticle.Fields.contentText] as? String {
					let data = Data(contentText.utf8) as NSData
					if let compressedData = try? data.compressed(using: .lzfse) {
						record[CloudKitArticle.Fields.contentTextData] = compressedData as Data
						record[CloudKitArticle.Fields.contentText] = nil
					}
				}

			}

			result.append(record)
		}

		return result
	}
}
