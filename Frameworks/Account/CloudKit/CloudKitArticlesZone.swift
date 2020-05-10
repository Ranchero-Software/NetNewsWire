//
//  CloudKitArticlesZone.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser
import RSWeb
import CloudKit
import Articles
import SyncDatabase

final class CloudKitArticlesZone: CloudKitZone {
	
	static var zoneID: CKRecordZone.ID {
		return CKRecordZone.ID(zoneName: "Articles", ownerName: CKCurrentUserDefaultName)
	}
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate? = nil
	
	struct CloudKitArticle {
		static let recordType = "Article"
		struct Fields {
			static let articleStatus = "articleStatus"
			static let webFeedURL = "webFeedURL"
			static let uniqueID = "uniqueID"
			static let title = "title"
			static let contentHTML = "contentHTML"
			static let contentText = "contentText"
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

		save(records, completion: completion)
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
				modifyRecords.append(makeStatusRecord(statusUpdate))
				modifyRecords.append(makeArticleRecord(statusUpdate.article!))
			case .new:
				newRecords.append(makeStatusRecord(statusUpdate))
				newRecords.append(makeArticleRecord(statusUpdate.article!))
			case .delete:
				deleteRecordIDs.append(CKRecord.ID(recordName: statusID(statusUpdate.articleID), zoneID: Self.zoneID))
			case .statusOnly:
				modifyRecords.append(makeStatusRecord(statusUpdate))
				deleteRecordIDs.append(CKRecord.ID(recordName: articleID(statusUpdate.articleID), zoneID: Self.zoneID))
			}
		}
		
		modify(recordsToSave: modifyRecords, recordIDsToDelete: deleteRecordIDs) { result in
			switch result {
			case .success:
				self.saveIfNew(newRecords) { result in
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
		let recordID = CKRecord.ID(recordName: statusID(article.articleID), zoneID: Self.zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
		if let webFeedExternalID = article.webFeed?.externalID {
			record[CloudKitArticleStatus.Fields.webFeedExternalID] = webFeedExternalID
		}
		record[CloudKitArticleStatus.Fields.read] = article.status.read ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = article.status.starred ? "1" : "0"
		return record
	}
	
	func makeStatusRecord(_ statusUpdate: CloudKitArticleStatusUpdate) -> CKRecord {
		let recordID = CKRecord.ID(recordName: statusID(statusUpdate.articleID), zoneID: Self.zoneID)
		let record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
		
		if let webFeedExternalID = statusUpdate.article?.webFeed?.externalID {
			record[CloudKitArticleStatus.Fields.webFeedExternalID] = webFeedExternalID
		}
		
		record[CloudKitArticleStatus.Fields.read] = statusUpdate.isRead ? "1" : "0"
		record[CloudKitArticleStatus.Fields.starred] = statusUpdate.isStarred ? "1" : "0"
		
		return record
	}
	
	func makeArticleRecord(_ article: Article) -> CKRecord {
		let recordID = CKRecord.ID(recordName: articleID(article.articleID), zoneID: Self.zoneID)
		let record = CKRecord(recordType: CloudKitArticle.recordType, recordID: recordID)

		let articleStatusRecordID = CKRecord.ID(recordName: statusID(article.articleID), zoneID: Self.zoneID)
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


}
