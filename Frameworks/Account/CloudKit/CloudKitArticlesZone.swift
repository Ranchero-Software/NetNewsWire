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
			static let hollow = "hollow"
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
			records.append(contentsOf: makeArticleRecords(saveArticle))
		}

		saveIfNew(records, completion: completion)
	}
	
	func deleteArticles(_ webFeedURL: String, completion: @escaping ((Result<Void, Error>) -> Void)) {
		let predicate = NSPredicate(format: "webFeedURL = %@", webFeedURL)
		let ckQuery = CKQuery(recordType: CloudKitArticle.recordType, predicate: predicate)
		delete(ckQuery: ckQuery, completion: completion)
	}
	
	func deleteArticles(_ articles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard !articles.isEmpty else {
			completion(.success(()))
			return
		}
		
		let recordIDs = articles.map { CKRecord.ID(recordName: $0.articleID, zoneID: Self.zoneID) }
		delete(recordIDs: recordIDs, completion: completion)
	}
	
	func modifyArticles(_ articles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard !articles.isEmpty else {
			completion(.success(()))
			return
		}
		
		var records = [CKRecord]()
		
		let saveArticles = articles.filter { $0.status.read == false || $0.status.starred == true }
		for saveArticle in saveArticles {
			records.append(contentsOf: makeArticleRecords(saveArticle))
		}

		let hollowArticles = articles.subtracting(saveArticles)
		for hollowArticle in hollowArticles {
			records.append(contentsOf: makeHollowArticleRecords(hollowArticle))
		}
		
		self.modify(recordsToSave: records, recordIDsToDelete: []) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				self.handleSendArticleStatusError(error, articles: articles, completion: completion)
			}
		}
	}
	
}

private extension CloudKitArticlesZone {

	func handleSendArticleStatusError(_ error: Error, articles: Set<Article>, completion: @escaping ((Result<Void, Error>) -> Void)) {
		if case CloudKitZoneError.userDeletedZone = error {
			self.createZoneRecord() { result in
				switch result {
				case .success:
					self.modifyArticles(articles, completion: completion)
				case .failure(let error):
					completion(.failure(error))
				}
			}
		} else {
			completion(.failure(error))
		}
	}
	
	func makeArticleRecords(_ article: Article) -> [CKRecord] {
		var records = [CKRecord]()

		let recordID = CKRecord.ID(recordName: article.articleID, zoneID: Self.zoneID)
		let articleRecord = CKRecord(recordType: CloudKitArticle.recordType, recordID: recordID)

		articleRecord[CloudKitArticle.Fields.hollow] = "0"
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
			articleRecord[CloudKitArticle.Fields.parsedAuthors] = parsedAuthors
		}
		
		articleRecord[CloudKitArticle.Fields.read] = article.status.read ? "1" : "0"
		articleRecord[CloudKitArticle.Fields.starred] = article.status.starred ? "1" : "0"
		
		records.append(articleRecord)
		return records
	}

	func makeHollowArticleRecords(_ article: Article) -> [CKRecord] {
		var records = [CKRecord]()

		let recordID = CKRecord.ID(recordName: article.articleID, zoneID: Self.zoneID)
		let articleRecord = CKRecord(recordType: CloudKitArticle.recordType, recordID: recordID)

		articleRecord[CloudKitArticle.Fields.hollow] = "1"
		articleRecord[CloudKitArticle.Fields.webFeedURL] = article.webFeed?.url
		articleRecord[CloudKitArticle.Fields.uniqueID] = nil
		articleRecord[CloudKitArticle.Fields.title] = nil
		articleRecord[CloudKitArticle.Fields.contentHTML] = nil
		articleRecord[CloudKitArticle.Fields.contentText] = nil
		articleRecord[CloudKitArticle.Fields.url] = nil
		articleRecord[CloudKitArticle.Fields.externalURL] = nil
		articleRecord[CloudKitArticle.Fields.summary] = nil
		articleRecord[CloudKitArticle.Fields.imageURL] = nil
		articleRecord[CloudKitArticle.Fields.datePublished] = nil
		articleRecord[CloudKitArticle.Fields.dateModified] = nil
		articleRecord[CloudKitArticle.Fields.parsedAuthors] =  nil
		articleRecord[CloudKitArticle.Fields.read] = article.status.read ? "1" : "0"
		articleRecord[CloudKitArticle.Fields.starred] = article.status.starred ? "1" : "0"
		
		records.append(articleRecord)
		return records
	}

}
