//
//  CloudKitArticlesZone.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Parser
import ParserObjC
import Web
import CloudKit
import Articles
import SyncDatabase

public protocol CloudKitFeedInfoDelegate {

	@MainActor func feedExternalID(article: Article) -> String?
	@MainActor func feedURL(article: Article) -> String?
}

@MainActor public final class CloudKitArticlesZone: CloudKitZone {

	public let zoneID: CKRecordZone.ID

	public var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	public weak var container: CKContainer?
	public weak var database: CKDatabase?
	public var delegate: CloudKitZoneDelegate? = nil
	public var feedInfoDelegate: CloudKitFeedInfoDelegate? = nil

	var compressionQueue = DispatchQueue(label: "Articles Zone Compression Queue")
	
	public struct CloudKitArticle {
		public static let recordType = "Article"
		public struct Fields {
			public static let articleStatus = "articleStatus"
			public static let feedURL = "webFeedURL"
			public static let uniqueID = "uniqueID"
			public static let title = "title"
			public static let contentHTML = "contentHTML"
			public static let contentHTMLData = "contentHTMLData"
			public static let contentText = "contentText"
			public static let contentTextData = "contentTextData"
			public static let url = "url"
			public static let externalURL = "externalURL"
			public static let summary = "summary"
			public static let imageURL = "imageURL"
			public static let datePublished = "datePublished"
			public static let dateModified = "dateModified"
			public static let parsedAuthors = "parsedAuthors"
		}
	}

	public struct CloudKitArticleStatus {
		public static let recordType = "ArticleStatus"
		public struct Fields {
			public static let feedExternalID = "webFeedExternalID"
			public static let read = "read"
			public static let starred = "starred"
		}
	}

	@MainActor public init(container: CKContainer) {
		self.container = container
		self.database = container.privateCloudDatabase
		self.zoneID = CKRecordZone.ID(zoneName: "Articles", ownerName: CKCurrentUserDefaultName)
		migrateChangeToken()
	}
	
	@MainActor public func refreshArticles() async throws {

		do {
			try await fetchChangesInZone()

		} catch {
			if case CloudKitZoneError.userDeletedZone = error {
				_ = try await self.createZoneRecord()
				try await refreshArticles()
			} else {
				throw error
			}
		}
	}

	public func deleteArticles(_ feedExternalID: String) async throws {

		let predicate = NSPredicate(format: "webFeedExternalID = %@", feedExternalID)
		let ckQuery = CKQuery(recordType: CloudKitArticleStatus.recordType, predicate: predicate)

		try await delete(ckQuery: ckQuery)
	}
	
	public func modifyArticles(_ statusUpdates: [CloudKitArticleStatusUpdate], completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard !statusUpdates.isEmpty else {
			completion(.success(()))
			return
		}

		Task { @MainActor in

			var modifyRecords = [CKRecord]()
			var newRecords = [CKRecord]()
			var deleteRecordIDs = [CKRecord.ID]()

			for statusUpdate in statusUpdates {
				switch statusUpdate.record {
				case .all:
					modifyRecords.append(self.makeStatusRecord(statusUpdate))
					modifyRecords.append(self.makeArticleRecord(statusUpdate.article!))
				case .new:
					newRecords.append(self.makeStatusRecord(statusUpdate))
					newRecords.append(self.makeArticleRecord(statusUpdate.article!))
				case .delete:
					deleteRecordIDs.append(CKRecord.ID(recordName: self.statusID(statusUpdate.articleID), zoneID: zoneID))
				case .statusOnly:
					modifyRecords.append(self.makeStatusRecord(statusUpdate))
					deleteRecordIDs.append(CKRecord.ID(recordName: self.articleID(statusUpdate.articleID), zoneID: zoneID))
				}
			}

			let compressedModifyRecords = await compressedArticleRecords(modifyRecords)

			do {
				try await self.modify(recordsToSave: compressedModifyRecords, recordIDsToDelete: deleteRecordIDs)

				let compressedNewRecords = await compressedArticleRecords(newRecords)
				try await self.saveIfNew(compressedNewRecords)

			} catch {
				self.handleModifyArticlesError(error, statusUpdates: statusUpdates, completion: completion)
			}
		}
	}
}

private extension CloudKitArticlesZone {

	@MainActor func handleModifyArticlesError(_ error: Error, statusUpdates: [CloudKitArticleStatusUpdate], completion: @escaping ((Result<Void, Error>) -> Void)) {
		if case CloudKitZoneError.userDeletedZone = error {

			Task { @MainActor in
				do {
					_ = try await self.createZoneRecord()
					self.modifyArticles(statusUpdates, completion: completion)
				} catch {
					completion(.failure(error))
				}
			}

		} else {
			completion(.failure(error))
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

		if let feedExternalID = feedInfoDelegate?.feedExternalID(article: article) {
			record[CloudKitArticleStatus.Fields.feedExternalID] = feedExternalID
		}

		record[CloudKitArticleStatus.Fields.read] = article.status.read ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = article.status.starred ? "1" : "0"
		return record
	}
	
	@MainActor func makeStatusRecord(_ statusUpdate: CloudKitArticleStatusUpdate) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(statusUpdate.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)

		if let article = statusUpdate.article, let feedExternalID = feedInfoDelegate?.feedExternalID(article: article) {
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
		record[CloudKitArticle.Fields.feedURL] = feedInfoDelegate?.feedURL(article: article)
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

	func compressedArticleRecords(_ records: [CKRecord]) async -> [CKRecord] {

		await withCheckedContinuation { continuation in
			self._compressedArticleRecords(records) { records in
				continuation.resume(returning: records)
			}
		}
	}

	func _compressedArticleRecords(_ records: [CKRecord], completion: @escaping @Sendable ([CKRecord]) -> Void) {

		compressionQueue.async {

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

			completion(result)
		}
	}
}
