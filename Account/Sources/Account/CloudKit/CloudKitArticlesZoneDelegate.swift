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
import RSWeb
import CloudKit
import SyncDatabase
import Articles
import ArticlesDatabase

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
	
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {
		
		database.selectPendingReadStatusArticleIDs() { result in
			switch result {
			case .success(let pendingReadStatusArticleIDs):

				self.database.selectPendingStarredStatusArticleIDs() { result in
					switch result {
					case .success(let pendingStarredStatusArticleIDs):

						self.delete(recordKeys: deleted, pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs) {
							self.update(records: changed,
										 pendingReadStatusArticleIDs: pendingReadStatusArticleIDs,
										 pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs,
										 completion: completion)
						}
						
					case .failure(let error):
						os_log(.error, log: self.log, "Error occurred geting pending starred records: %@", error.localizedDescription)
						completion(.failure(CloudKitZoneError.unknown))
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "Error occurred getting pending read status records: %@", error.localizedDescription)
				completion(.failure(CloudKitZoneError.unknown))
			}

		}
		
	}
	
}

private extension CloudKitArticlesZoneDelegate {

	func delete(recordKeys: [CloudKitRecordKey], pendingStarredStatusArticleIDs: Set<String>, completion: @escaping () -> Void) {
		let receivedRecordIDs = recordKeys.filter({ $0.recordType == CloudKitArticlesZone.CloudKitArticleStatus.recordType }).map({ $0.recordID })
		let receivedArticleIDs = Set(receivedRecordIDs.map({ stripPrefix($0.externalID) }))
		let deletableArticleIDs = receivedArticleIDs.subtracting(pendingStarredStatusArticleIDs)
		
		guard !deletableArticleIDs.isEmpty else {
			completion()
			return
		}
		
		database.deleteSelectedForProcessing(Array(deletableArticleIDs)) { _ in
			self.account?.delete(articleIDs: deletableArticleIDs) { _ in
				completion()
			}
		}
	}

	func update(records: [CKRecord], pendingReadStatusArticleIDs: Set<String>, pendingStarredStatusArticleIDs: Set<String>, completion: @escaping (Result<Void, Error>) -> Void) {

		let receivedUnreadArticleIDs = Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "0" }).map({ stripPrefix($0.externalID) }))
		let receivedReadArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "1" }).map({ stripPrefix($0.externalID) }))
		let receivedUnstarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "0" }).map({ stripPrefix($0.externalID) }))
		let receivedStarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "1" }).map({ stripPrefix($0.externalID) }))

		let updateableUnreadArticleIDs = receivedUnreadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableReadArticleIDs = receivedReadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableUnstarredArticleIDs = receivedUnstarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)
		let updateableStarredArticleIDs = receivedStarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		var errorOccurred = false
		let group = DispatchGroup()
		
		group.enter()
		account?.markAsUnread(updateableUnreadArticleIDs) { result in
			if case .failure(let databaseError) = result {
				errorOccurred = true
				os_log(.error, log: self.log, "Error occurred while storing unread statuses: %@", databaseError.localizedDescription)
			}
			group.leave()
		}
		
		group.enter()
		account?.markAsRead(updateableReadArticleIDs) { result in
			if case .failure(let databaseError) = result {
				errorOccurred = true
				os_log(.error, log: self.log, "Error occurred while storing read statuses: %@", databaseError.localizedDescription)
			}
			group.leave()
		}
		
		group.enter()
		account?.markAsUnstarred(updateableUnstarredArticleIDs) { result in
			if case .failure(let databaseError) = result {
				errorOccurred = true
				os_log(.error, log: self.log, "Error occurred while storing unstarred statuses: %@", databaseError.localizedDescription)
			}
			group.leave()
		}
		
		group.enter()
		account?.markAsStarred(updateableStarredArticleIDs) { result in
			if case .failure(let databaseError) = result {
				errorOccurred = true
				os_log(.error, log: self.log, "Error occurred while storing starred statuses: %@", databaseError.localizedDescription)
			}
			group.leave()
		}
		
		group.enter()
		DispatchQueue.global(qos: .utility).async {
			let parsedItems = records.compactMap { self.makeParsedItem($0) }
			let webFeedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
			
			DispatchQueue.main.async {
				for (webFeedID, parsedItems) in webFeedIDsAndItems {
					group.enter()
					self.account?.update(webFeedID, with: parsedItems, deleteOlder: false) { result in
						switch result {
						case .success(let articleChanges):
							guard let deletes = articleChanges.deletedArticles, !deletes.isEmpty else {
								group.leave()
								return
							}
							let syncStatuses = deletes.map { SyncStatus(articleID: $0.articleID, key: .deleted, flag: true) }
							try? self.database.insertStatuses(syncStatuses)
							group.leave()
						case .failure(let databaseError):
							errorOccurred = true
							os_log(.error, log: self.log, "Error occurred while storing articles: %@", databaseError.localizedDescription)
							group.leave()
						}
					}
				}
				group.leave()
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			if errorOccurred {
				completion(.failure(CloudKitZoneError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}
	
	func stripPrefix(_ externalID: String) -> String {
		return String(externalID[externalID.index(externalID.startIndex, offsetBy: 2)..<externalID.endIndex])
	}

	func makeParsedItem(_ articleRecord: CKRecord) -> ParsedItem? {
		guard articleRecord.recordType == CloudKitArticlesZone.CloudKitArticle.recordType else {
			return nil
		}
		
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
