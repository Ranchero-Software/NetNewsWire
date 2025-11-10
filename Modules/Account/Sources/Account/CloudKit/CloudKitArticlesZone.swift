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

	var zoneID: CKRecordZone.ID

	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate? = nil

	let compressionQueue = DispatchQueue(label: "Articles Zone Compression Queue")

	struct CloudKitArticle {
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

	struct CloudKitArticleStatus {
		static let recordType = "ArticleStatus"
		struct Fields {
			static let feedExternalID = "webFeedExternalID"
			static let read = "read"
			static let starred = "starred"
		}
	}

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

	func saveNewArticles(_ articles: Set<Article>) async throws {
		guard !articles.isEmpty else {
			return
		}

		var records = [CKRecord]()

		let saveArticles = articles.filter { $0.status.read == false || $0.status.starred == true }
		for saveArticle in saveArticles {
			records.append(makeStatusRecord(saveArticle))
			records.append(makeArticleRecord(saveArticle))
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

	func modifyArticles(_ statusUpdates: [CloudKitArticleStatusUpdate]) async throws {
		guard !statusUpdates.isEmpty else {
			return
		}

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

}

private extension CloudKitArticlesZone {

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

	func makeStatusRecord(_ article: Article) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(article.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
		if let feedExternalID = article.feed?.externalID {
			record[CloudKitArticleStatus.Fields.feedExternalID] = feedExternalID
		}
		record[CloudKitArticleStatus.Fields.read] = article.status.read ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = article.status.starred ? "1" : "0"
		return record
	}

	func makeStatusRecord(_ statusUpdate: CloudKitArticleStatusUpdate) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(statusUpdate.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)

		if let feedExternalID = statusUpdate.article?.feed?.externalID {
			record[CloudKitArticleStatus.Fields.feedExternalID] = feedExternalID
		}

		record[CloudKitArticleStatus.Fields.read] = statusUpdate.isRead ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = statusUpdate.isStarred ? "1" : "0"

		return record
	}

	func makeArticleRecord(_ article: Article) -> CKRecord {
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

	func compressArticleRecords(_ records: [CKRecord]) -> [CKRecord] {
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
