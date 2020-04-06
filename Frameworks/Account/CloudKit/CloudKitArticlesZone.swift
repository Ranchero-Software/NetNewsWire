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
			static let read = "read"
			static let starred = "starred"
			static let userDeleted = "userDeleted"
		}
	}
	
	init(container: CKContainer) {
		self.container = container
		self.database = container.privateCloudDatabase
	}
	
	func refreshArticleStatus(completion: @escaping ((Result<Void, Error>) -> Void)) {
		fetchChangesInZone() { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				if case CloudKitZoneError.userDeletedZone = error {
					self.createZoneRecord() { result in
						switch result {
						case .success:
							self.refreshArticleStatus(completion: completion)
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
	
	func sendArticleStatus(_ syncStatuses: [SyncStatus], starredArticles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		var records = makeStatusRecords(syncStatuses)
		makeArticleRecordsIfNecessary(starredArticles) { result in
			switch result {
			case .success(let articleRecords):
				records.append(contentsOf: articleRecords)
				self.modify(recordsToSave: records, recordIDsToDelete: []) { result in
					switch result {
					case .success:
						completion(.success(()))
					case .failure(let error):
						self.handleSendArticleStatusError(error, syncStatuses: syncStatuses, starredArticles: starredArticles, completion: completion)
					}
				}
			case .failure(let error):
				self.handleSendArticleStatusError(error, syncStatuses: syncStatuses, starredArticles: starredArticles, completion: completion)
			}
		}
	}
	
	func handleSendArticleStatusError(_ error: Error, syncStatuses: [SyncStatus], starredArticles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		if case CloudKitZoneError.userDeletedZone = error {
			self.createZoneRecord() { result in
				switch result {
				case .success:
					self.sendArticleStatus(syncStatuses, starredArticles: starredArticles, completion: completion)
				case .failure(let error):
					completion(.failure(error))
				}
			}
		} else {
			completion(.failure(error))
		}
	}
	
}

private extension CloudKitArticlesZone {
	
	func makeStatusRecords(_ syncStatuses: [SyncStatus]) -> [CKRecord] {
		var records = [String: CKRecord]()
		
		for status in syncStatuses {
			
			var record = records[status.articleID]
			if record == nil {
				let recordID = CKRecord.ID(recordName: status.articleID, zoneID: Self.zoneID)
				record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
				records[status.articleID] = record
			}
			
			switch status.key {
			case .read:
				record![CloudKitArticleStatus.Fields.read] = status.flag ? "1" : "0"
			case .starred:
				record![CloudKitArticleStatus.Fields.starred] = status.flag ? "1" : "0"
			case .userDeleted:
				record![CloudKitArticleStatus.Fields.userDeleted] = status.flag ? "1" : "0"
			}
		}
		
		return Array(records.values)
	}

	func makeArticleRecordsIfNecessary(_ articles: Set<Article>, completion: @escaping ((Result<[CKRecord], Error>) -> Void)) {
		let group = DispatchGroup()
		var errorOccurred = false
		var records = [CKRecord]()

		for article in articles {
			
			let statusRecordID = CKRecord.ID(recordName: article.articleID, zoneID: Self.zoneID)
			let statusRecordRef = CKRecord.Reference(recordID: statusRecordID, action: .deleteSelf)
			let predicate = NSPredicate(format: "articleStatus = %@", statusRecordRef)
			let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)

			group.enter()
			exists(ckQuery) { result in
				switch result {
				case .success(let recordFound):
					if !recordFound {
						records.append(contentsOf:  self.makeArticleRecords(article))
					}
				case .failure(let error):
					errorOccurred = true
					os_log(.error, log: self.log, "Error occurred while checking for existing articles: %@", error.localizedDescription)
				}
				group.leave()
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			if errorOccurred {
				completion(.failure(CloudKitZoneError.unknown))
			} else {
				completion(.success(records))
			}
		}
	}
	
	func makeArticleRecords(_ article: Article) -> [CKRecord] {
		var records = [CKRecord]()

		let articleRecord = CKRecord(recordType: CloudKitArticle.recordType, recordID: generateRecordID())

		let articleStatusRecordID = CKRecord.ID(recordName: article.articleID, zoneID: Self.zoneID)
		articleRecord[CloudKitArticle.Fields.articleStatus] = CKRecord.Reference(recordID: articleStatusRecordID, action: .deleteSelf)
		articleRecord[CloudKitArticle.Fields.webFeedURL] = article.webFeed?.url
		articleRecord[CloudKitArticle.Fields.uniqueID] = article.uniqueID
		articleRecord[CloudKitArticle.Fields.title] = article.title
		articleRecord[CloudKitArticle.Fields.contentHTML] = article.contentHTML
		articleRecord[CloudKitArticle.Fields.contentText] = article.contentText
		articleRecord[CloudKitArticle.Fields.url] = article.url
		articleRecord[CloudKitArticle.Fields.externalURL] = article.externalURL
		articleRecord[CloudKitArticle.Fields.summary] = article.summary
		articleRecord[CloudKitArticle.Fields.imageURL] = article.imageURL
		articleRecord[CloudKitArticle.Fields.datePublished] = article.datePublished
		articleRecord[CloudKitArticle.Fields.dateModified] = article.dateModified
		
		let encoder = JSONEncoder()
		var parsedAuthors = [String]()
		
		if let authors = article.authors {
			for author in authors {
				let parsedAuthor = ParsedAuthor(name: author.name,
												url: author.url,
												avatarURL: author.avatarURL,
												emailAddress: author.emailAddress)
				if let data = try? encoder.encode(parsedAuthor), let encodedParsedAuthor = String(data: data, encoding: .utf8) {
					parsedAuthors.append(encodedParsedAuthor)
				}
			}
		}
		
		articleRecord[CloudKitArticle.Fields.parsedAuthors] = parsedAuthors
		
		records.append(articleRecord)
		return records
	}


}
