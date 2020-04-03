//
//  CloudKitArticlesZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser
import CloudKit
import SyncDatabase

class CloudKitArticlesZoneDelegate: CloudKitZoneDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var account: Account?
	var database: SyncDatabase
	weak var articlesZone: CloudKitArticlesZone?
	
	init(account: Account, database: SyncDatabase, articlesZone: CloudKitArticlesZone) {
		self.account = account
		self.database = database
		self.articlesZone = articlesZone
	}
	
	func cloudKitDidChange(record: CKRecord) {

	}
	
	func cloudKitDidDelete(recordKey: CloudKitRecordKey) {
		// Article downloads clean up old articles and statuses
	}
	
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {
		
		database.selectPendingReadStatusArticleIDs() { result in
			switch result {
			case .success(let pendingReadStatusArticleIDs):

				self.database.selectPendingStarredStatusArticleIDs() { result in
					switch result {
					case .success(let pendingStarredStatusArticleIDs):
						
						self.process(records: changed,
									 pendingReadStatusArticleIDs: pendingReadStatusArticleIDs,
									 pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs,
									 completion: completion)
						
					case .failure(let error):
						os_log(.error, log: self.log, "Error occurred geting pending starred records: %@", error.localizedDescription)
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "Error occurred getting pending read status records: %@", error.localizedDescription)
			}

		}
		
	}
	
}

private extension CloudKitArticlesZoneDelegate {
	
	func process(records: [CKRecord], pendingReadStatusArticleIDs: Set<String>, pendingStarredStatusArticleIDs: Set<String>, completion: @escaping (Result<Void, Error>) -> Void) {

		let receivedUnreadArticleIDs = Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "0" }).map({ $0.externalID }))
		let receivedReadArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "1" }).map({ $0.externalID }))
		let receivedUnstarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "0" }).map({ $0.externalID }))
		let receivedStarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "1" }).map({ $0.externalID }))

		let receivedStarredArticles = records.filter({ $0.recordType == CloudKitArticlesZone.CloudKitArticle.recordType })
		
		let updateableUnreadArticleIDs = receivedUnreadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableReadArticleIDs = receivedReadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableUnstarredArticleIDs = receivedUnstarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)
		let updateableStarredArticleIDs = receivedStarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		let group = DispatchGroup()
		
		group.enter()
		account?.markAsUnread(updateableUnreadArticleIDs) { _ in
			group.leave()
		}
		
		group.enter()
		account?.markAsRead(updateableReadArticleIDs) { _ in
			group.leave()
		}
		
		group.enter()
		account?.markAsUnstarred(updateableUnstarredArticleIDs) { _ in
			group.leave()
		}
		
		group.enter()
		account?.markAsStarred(updateableStarredArticleIDs) { _ in
			group.leave()
		}
		
		for receivedStarredArticle in receivedStarredArticles {
			if let parsedItem = makeParsedItem(receivedStarredArticle) {
				group.enter()
				self.account?.update(parsedItem.feedURL, with: Set([parsedItem])) { databaseError in
					group.leave()
					if let databaseError = databaseError {
						os_log(.error, log: self.log, "Error occurred while storing starred items: %@", databaseError.localizedDescription)
					}
				}
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
		
	}

	
	func makeParsedItem(_ articleRecord: CKRecord) -> ParsedItem? {
		var parsedAuthors = Set<ParsedAuthor>()
		
		let decoder = JSONDecoder()
		
		if let encodedParsedAuthors = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.parsedAuthors] as? [String] {
			for encodedParsedAuthor in encodedParsedAuthors {
				if let data = encodedParsedAuthor.data(using: .utf8), let parsedAuthor = try? decoder.decode(ParsedAuthor.self, from: data) {
					parsedAuthors.insert(parsedAuthor)
				}
			}
		}
		
		guard let uniqueID = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.uniqueID] as? String,
			let webFeedURL = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.webFeedURL] as? String else {
			return nil
		}
		
		let parsedItem = ParsedItem(syncServiceID: nil,
									uniqueID: uniqueID,
									feedURL: webFeedURL,
									url: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.url] as? String,
									externalURL: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.externalURL] as? String,
									title: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.title] as? String,
									language: nil,
									contentHTML: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.contentHTML] as? String,
									contentText: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.contentText] as? String,
									summary: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.summary] as? String,
									imageURL: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.imageURL] as? String,
									bannerImageURL: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.imageURL] as? String,
									datePublished: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.datePublished] as? Date,
									dateModified: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.dateModified] as? Date,
									authors: parsedAuthors,
									tags: nil,
									attachments: nil)
		
		return parsedItem
	}
	
}
