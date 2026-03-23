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
	private static let recordFetchChunkSize = 200
	private static let cleanUpLimit = 200

	struct StatusRecordInfo {
		let read: Bool
		let starred: Bool
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
	}

	var zoneID: CKRecordZone.ID

	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate?

	let compressionQueue = DispatchQueue(label: "Articles Zone Compression Queue")

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

	var settings: (any CloudKitSettings)!

	init(container: CKContainer) {
		self.container = container
		self.database = container.privateCloudDatabase
		self.zoneID = CKRecordZone.ID(zoneName: "Articles", ownerName: CKCurrentUserDefaultName)
		migrateChangeToken()
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

		let syncUnreadContent = settings.syncArticleContentForUnreadArticles
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

		let syncUnreadContent = settings.syncArticleContentForUnreadArticles
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

	/// Cleans up stale CloudKit records. Deletes up to `limit` records total:
	/// - Article content records that are read + not starred
	/// - Article content records that are unread + not starred when syncUnreadContent is off
	/// - Article content records with no status reference (orphaned)
	/// - ArticleStatus records that are stale (unstarred, older than 6 months, no local article)
	func cleanUpRecords(account: Account, syncUnreadContent: Bool, dryRun: Bool, limit: Int = CloudKitArticlesZone.cleanUpLimit) async throws -> Int {
		guard database != nil else {
			return 0
		}

		var deleteRecordIDs = try await contentRecordIDsToDelete(syncUnreadContent: syncUnreadContent, limit: limit)
		Self.logger.info("CloudKitArticlesZone: cleanUpRecords: \(deleteRecordIDs.count, privacy: .public) content records to delete")

		if deleteRecordIDs.count < limit {
			let statusIDs = try await staleStatusRecordIDsToDelete(account: account, limit: limit - deleteRecordIDs.count)
			Self.logger.info("CloudKitArticlesZone: cleanUpRecords: \(statusIDs.count, privacy: .public) status records to delete")
			deleteRecordIDs.append(contentsOf: statusIDs)
		}

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

		return makeStats(statusScan, contentScan)
	}
}

private extension CloudKitArticlesZone {

	// MARK: - Record Cleanup Helpers

	/// Returns content record IDs to delete: orphaned records (no status reference),
	/// read + unstarred records, and unread + unstarred records when syncUnreadContent is off.
	func contentRecordIDsToDelete(syncUnreadContent: Bool, limit: Int) async throws -> [CKRecord.ID] {
		guard let database else {
			return []
		}

		Self.logger.info("CloudKitArticlesZone: querying article content records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)
		let contentRecords = try await query(ckQuery, desiredKeys: [CloudKitArticle.Fields.articleStatus])
		Self.logger.info("CloudKitArticlesZone: fetched \(contentRecords.count, privacy: .public) article content records")

		var deleteRecordIDs = [CKRecord.ID]()
		var articleRecordsByStatusID = [CKRecord.ID: CKRecord.ID]()

		// Map each content record to its status record ID.
		// Content records without a status reference are orphaned — mark for deletion.
		for record in contentRecords {
			guard let reference = record[CloudKitArticle.Fields.articleStatus] as? CKRecord.Reference else {
				deleteRecordIDs.append(record.recordID)
				continue
			}
			articleRecordsByStatusID[reference.recordID] = record.recordID
		}

		let statusDesiredKeys = [CloudKitArticleStatus.Fields.read, CloudKitArticleStatus.Fields.starred]

		// Fetch status records in chunks to decide which content records to delete.
		// Stop once we hit the deletion limit.
		for chunk in Array(articleRecordsByStatusID.keys).chunked(into: Self.recordFetchChunkSize) {
			if deleteRecordIDs.count >= limit {
				break
			}

			let results = try await database.records(for: chunk, desiredKeys: statusDesiredKeys)
			for (statusID, result) in results {
				if deleteRecordIDs.count >= limit {
					break
				}
				guard let articleRecordID = articleRecordsByStatusID[statusID] else {
					continue
				}
				switch result {
				case .success(let statusRecord):
					let starred = statusRecord[CloudKitArticleStatus.Fields.starred] as? String ?? "0"
					let read = statusRecord[CloudKitArticleStatus.Fields.read] as? String ?? "1"

					// Never delete content for starred articles.
					if starred == "1" {
						continue
					}
					// Delete content for read articles, or for unread articles
					// when unread content syncing is off.
					if read == "1" || !syncUnreadContent {
						deleteRecordIDs.append(articleRecordID)
					}
				case .failure:
					// Status record not found — content is orphaned, delete it.
					deleteRecordIDs.append(articleRecordID)
				}
			}
		}

		return deleteRecordIDs
	}

	/// Returns stale status record IDs to delete: unstarred, older than 6 months,
	/// with no corresponding local article.
	func staleStatusRecordIDsToDelete(account: Account, limit: Int) async throws -> [CKRecord.ID] {
		Self.logger.info("CloudKitArticlesZone: querying status records for stale candidates")
		let cutoffDate = Date(timeIntervalSinceNow: -Self.staleStatusRecordInterval)
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let ckQuery = CKQuery(recordType: CloudKitArticleStatus.recordType, predicate: predicate)
		let desiredKeys = [CloudKitArticleStatus.Fields.read, CloudKitArticleStatus.Fields.starred]
		let statusRecords = try await query(ckQuery, desiredKeys: desiredKeys)
		Self.logger.info("CloudKitArticlesZone: fetched \(statusRecords.count, privacy: .public) status records")

		var staleCandidates = [(articleID: String, recordID: CKRecord.ID)]()

		for record in statusRecords {
			let starred = record[CloudKitArticleStatus.Fields.starred] as? String ?? "0"

			// Stale candidate: unstarred and older than 6 months
			if starred == "0", let creationDate = record.creationDate, creationDate < cutoffDate {
				let baseID = String(record.recordID.recordName.dropFirst(2))
				staleCandidates.append((baseID, record.recordID))
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
				let read = record[CloudKitArticleStatus.Fields.read] as? String ?? "1"
				let starred = record[CloudKitArticleStatus.Fields.starred] as? String ?? "0"
				let isRead = read != "0"
				let isStarred = starred == "1"

				statusByRecordID[record.recordID] = StatusRecordInfo(read: isRead, starred: isStarred)

				if isStarred {
					starredCount += 1
				}
				if isRead {
					readCount += 1
				} else {
					unreadCount += 1
				}

				if !isStarred, let creationDate = record.creationDate, creationDate < cutoffDate {
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
			return ArticleRecordScanResult(total: 0, starred: 0, unread: 0, read: 0, orphaned: 0)
		}

		Self.logger.info("CloudKitArticlesZone: scanArticleContentRecords: querying all Article records")
		let predicate = NSPredicate(format: "creationDate >= %@", Date.distantPast as CVarArg)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)

		var totalCount = 0
		var starredCount = 0
		var unreadCount = 0
		var readCount = 0
		var orphanedCount = 0

		try await queryPaginated(ckQuery, desiredKeys: [CloudKitArticle.Fields.articleStatus]) { pageRecords in
			try Task.checkCancellation()
			for record in pageRecords {
				guard let reference = record[CloudKitArticle.Fields.articleStatus] as? CKRecord.Reference else {
					orphanedCount += 1
					continue
				}
				if let statusInfo = statusByRecordID[reference.recordID] {
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
				}
			}
			totalCount += pageRecords.count
			await progress(ArticleRecordScanResult(total: totalCount, starred: starredCount, unread: unreadCount, read: readCount, orphaned: orphanedCount))
		}

		Self.logger.info("CloudKitArticlesZone: scanArticleContentRecords: final — total: \(totalCount, privacy: .public), starred: \(starredCount, privacy: .public), unread: \(unreadCount, privacy: .public), read: \(readCount, privacy: .public), orphaned: \(orphanedCount, privacy: .public)")
		return ArticleRecordScanResult(total: totalCount, starred: starredCount, unread: unreadCount, read: readCount, orphaned: orphanedCount)
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
