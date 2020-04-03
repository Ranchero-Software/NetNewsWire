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
		makeArticleRecordsIfNecessary(starredArticles) { result in
			switch result {
			case .success(let articleRecords):
				records.append(contentsOf: articleRecords)
				self.modify(recordsToSave: records, recordIDsToDelete: [], completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func fetchArticle(articleID: String, completion: @escaping ((Result<(String, ParsedItem), Error>) -> Void)) {
		
		let statusRecordID = CKRecord.ID(recordName: articleID, zoneID: Self.zoneID)
		let statusRecordRef = CKRecord.Reference(recordID: statusRecordID, action: .deleteSelf)
		let predicate = NSPredicate(format: "articleStatus = %@", statusRecordRef)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)
		
		query(ckQuery) { result in
			
			switch result {
			case .success(let articleRecords):
				if articleRecords.count == 1 {
					let articleRecord = articleRecords[0]
					
					let articleRef = CKRecord.Reference(record: articleRecord, action: .deleteSelf)
					let predicate = NSPredicate(format: "article = %@", articleRef)
					let ckQuery = CKQuery(recordType: CloudKitAuthor.recordType, predicate: predicate)

					self.query(ckQuery) { result in
						switch result {
						case .success(let authorRecords):
							if let webFeedID = articleRecord[CloudKitArticle.Fields.webFeedID] as? String, let parsedItem = self.makeParsedItem(articleRecord, authorRecords) {
								completion(.success((webFeedID, parsedItem)))
							} else {
								completion(.failure(CloudKitZoneError.unknown))
							}
						case .failure(let error):
							completion(.failure(error))
						}
					}
					
				} else {
					completion(.failure(CloudKitZoneError.unknown))
				}
			case .failure(let error):
				completion(.failure(error))
			}
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
		articleRecord[CloudKitArticle.Fields.webFeedID] = article.webFeedID
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
		
		records.append(articleRecord)
		
		if let authors = article.authors {
			for author in authors {
				let authorRecord = CKRecord(recordType: CloudKitAuthor.recordType, recordID: generateRecordID())
				authorRecord[CloudKitAuthor.Fields.article] = CKRecord.Reference(record: articleRecord, action: .deleteSelf)
				authorRecord[CloudKitAuthor.Fields.authorID] = author.authorID
				authorRecord[CloudKitAuthor.Fields.name] = author.name
				authorRecord[CloudKitAuthor.Fields.url] = author.url
				authorRecord[CloudKitAuthor.Fields.avatarURL] = author.avatarURL
				authorRecord[CloudKitAuthor.Fields.emailAddress] = author.emailAddress
				records.append(authorRecord)
			}
		}
		
		return records
	}
	
	func makeParsedItem(_ articleRecord: CKRecord, _ authorRecords: [CKRecord]) -> ParsedItem? {
		var parsedAuthors = Set<ParsedAuthor>()
		
		for authorRecord in authorRecords {
			let parsedAuthor = ParsedAuthor(name: authorRecord[CloudKitAuthor.Fields.name] as? String,
											url: authorRecord[CloudKitAuthor.Fields.url] as? String,
											avatarURL: authorRecord[CloudKitAuthor.Fields.avatarURL] as? String,
											emailAddress: authorRecord[CloudKitAuthor.Fields.emailAddress] as? String)
			parsedAuthors.insert(parsedAuthor)
		}
		
		guard let uniqueID = articleRecord[CloudKitArticle.Fields.uniqueID] as? String,
			let feedURL = articleRecord[CloudKitArticle.Fields.webFeedID] as? String else {
			return nil
		}
		
		let parsedItem = ParsedItem(syncServiceID: nil,
									uniqueID: uniqueID,
									feedURL: feedURL,
									url: articleRecord[CloudKitArticle.Fields.url] as? String,
									externalURL: articleRecord[CloudKitArticle.Fields.externalURL] as? String,
									title: articleRecord[CloudKitArticle.Fields.title] as? String,
									contentHTML: articleRecord[CloudKitArticle.Fields.contentHTML] as? String,
									contentText: articleRecord[CloudKitArticle.Fields.contentText] as? String,
									summary: articleRecord[CloudKitArticle.Fields.summary] as? String,
									imageURL: articleRecord[CloudKitArticle.Fields.imageURL] as? String,
									bannerImageURL: articleRecord[CloudKitArticle.Fields.imageURL] as? String,
									datePublished: articleRecord[CloudKitArticle.Fields.datePublished] as? Date,
									dateModified: articleRecord[CloudKitArticle.Fields.dateModified] as? Date,
									authors: parsedAuthors,
									tags: nil,
									attachments: nil)
		
		return parsedItem
	}

}
