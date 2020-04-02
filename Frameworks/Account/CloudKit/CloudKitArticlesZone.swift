//
//  CloudKitArticlesZone.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
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
			static let webFeedID = "webFeedID"
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
			static let authors = "authors"
		}
	}

	struct CloudKitAuthor {
		static let recordType = "Author"
		struct Fields {
			static let article = "article"
			static let authorID = "authorID"
			static let name = "name"
			static let url = "url"
			static let avatarURL = "avatarURL"
			static let emailAddress = "emailAddress"
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
	
	func sendArticleStatus(_ syncStatuses: [SyncStatus], starredArticles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		var records = makeStatusRecords(syncStatuses)
		records.append(contentsOf: makeArticleRecords(starredArticles))
		modify(recordsToSave: records, recordIDsToDelete: [], completion: completion)
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

	func makeArticleRecords(_ articles: Set<Article>) -> [CKRecord] {
		var records = [CKRecord]()

		for article in articles {
			
			let record = CKRecord(recordType: CloudKitArticle.recordType, recordID: generateRecordID())

			let articleStatusRecordID = CKRecord.ID(recordName: article.articleID, zoneID: Self.zoneID)
			record[CloudKitArticle.Fields.articleStatus] = CKRecord.Reference(recordID: articleStatusRecordID, action: .deleteSelf)
			record[CloudKitArticle.Fields.webFeedID] = article.webFeedID
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
			
			records.append(record)
			
			if let authors = article.authors {
				for author in authors {
					records.append(makeAuthorRecord(record, author))
				}
			}
		}
		
		return records
	}
	
	func makeAuthorRecord(_ articleRecord: CKRecord, _ author: Author) -> CKRecord {
		let record = CKRecord(recordType: CloudKitAuthor.recordType, recordID: generateRecordID())
		
		record[CloudKitAuthor.Fields.article] = CKRecord.Reference(record: articleRecord, action: .deleteSelf)
		record[CloudKitAuthor.Fields.authorID] = author.authorID
		record[CloudKitAuthor.Fields.name] = author.name
		record[CloudKitAuthor.Fields.url] = author.url
		record[CloudKitAuthor.Fields.avatarURL] = author.avatarURL
		record[CloudKitAuthor.Fields.emailAddress] = author.emailAddress
		
		return record
	}

}
