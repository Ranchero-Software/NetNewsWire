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

final class CloudKitArticlesZone: CloudKitZone {
	
	var zoneID: CKRecordZone.ID
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate? = nil
	
	var compressionQueue = DispatchQueue(label: "Articles Zone Compression Queue")
	
	struct CloudKitArticle {
		static let recordType = "Article"
		struct Fields {
			static let articleStatus = "articleStatus"
			static let webFeedURL = "webFeedURL"
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
			static let webFeedExternalID = "webFeedExternalID"
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
	
	func refreshArticles(completion: @escaping ((Result<Void, Error>) -> Void)) {
		fetchChangesInZone() { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				if case CloudKitZoneError.userDeletedZone = error {
					self.createZoneRecord() { result in
						switch result {
						case .success:
							self.refreshArticles(completion: completion)
						case .failure(let error):
							completion(.failure(error))
						}
					}
				} else {
					completion(.failure(error))
				}
			}
		}
	}
	
	func saveNewArticles(_ articles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard !articles.isEmpty else {
			completion(.success(()))
			return
		}
		
		var records = [CKRecord]()
		
		let saveArticles = articles.filter { $0.status.read == false || $0.status.starred == true }
		for saveArticle in saveArticles {
			records.append(makeStatusRecord(saveArticle))
			records.append(makeArticleRecord(saveArticle))
		}

		compressionQueue.async {
			let compressedRecords = self.compressArticleRecords(records)
			self.save(compressedRecords, completion: completion)
		}
	}
	
	func deleteArticles(_ webFeedExternalID: String, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let predicate = NSPredicate(format: "webFeedExternalID = %@", webFeedExternalID)
		let ckQuery = CKQuery(recordType: CloudKitArticleStatus.recordType, predicate: predicate)
		delete(ckQuery: ckQuery, completion: completion)
	}
	
	func modifyArticles(_ statusUpdates: [CloudKitArticleStatusUpdate], completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard !statusUpdates.isEmpty else {
			completion(.success(()))
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

		compressionQueue.async {
			let compressedModifyRecords = self.compressArticleRecords(modifyRecords)
			self.modify(recordsToSave: compressedModifyRecords, recordIDsToDelete: deleteRecordIDs) { result in
				switch result {
				case .success:
					let compressedNewRecords = self.compressArticleRecords(newRecords)
					self.saveIfNew(compressedNewRecords) { result in
						switch result {
						case .success:
							completion(.success(()))
						case .failure(let error):
							completion(.failure(error))
						}
					}
				case .failure(let error):
					self.handleModifyArticlesError(error, statusUpdates: statusUpdates, completion: completion)
				}
			}
		}
		
	}
	
}

private extension CloudKitArticlesZone {

	func handleModifyArticlesError(_ error: Error, statusUpdates: [CloudKitArticleStatusUpdate], completion: @escaping ((Result<Void, Error>) -> Void)) {
		if case CloudKitZoneError.userDeletedZone = error {
			self.createZoneRecord() { result in
				switch result {
				case .success:
					self.modifyArticles(statusUpdates, completion: completion)
				case .failure(let error):
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
	
	func makeStatusRecord(_ article: Article) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(article.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
		if let webFeedExternalID = article.webFeed?.externalID {
			record[CloudKitArticleStatus.Fields.webFeedExternalID] = webFeedExternalID
		}
		record[CloudKitArticleStatus.Fields.read] = article.status.read ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = article.status.starred ? "1" : "0"
		return record
	}
	
	func makeStatusRecord(_ statusUpdate: CloudKitArticleStatusUpdate) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(statusUpdate.articleID), zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
		
		if let webFeedExternalID = statusUpdate.article?.webFeed?.externalID {
			record[CloudKitArticleStatus.Fields.webFeedExternalID] = webFeedExternalID
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
		record[CloudKitArticle.Fields.webFeedURL] = article.webFeed?.url
		record[CloudKitArticle.Fields.uniqueID] = article.uniqueID
		record[CloudKitArticle.Fields.title] = article.title
		record[CloudKitArticle.Fields.contentHTML] = article.contentHTML
		record[CloudKitArticle.Fields.contentText] = article.contentText
		record[CloudKitArticle.Fields.url] = article.url
		record[CloudKitArticle.Fields.externalURL] = article.externalURL
		record[CloudKitArticle.Fields.summary] = article.summary
		record[CloudKitArticle.Fields.imageURL] = article.imageURL
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
