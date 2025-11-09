//
//  CloudKitArticlesZoneDelegate.swift
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
import SyncDatabase
import Articles
import ArticlesDatabase
import CloudKitSync

final class CloudKitArticlesZoneDelegate: CloudKitZoneDelegate {

	private static let logger = cloudKitLogger

	weak var account: Account?
	var syncDatabase: SyncDatabase
	weak var articlesZone: CloudKitArticlesZone?

	init(account: Account, database: SyncDatabase, articlesZone: CloudKitArticlesZone) {
		self.account = account
		self.syncDatabase = database
		self.articlesZone = articlesZone
	}

	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey]) async throws {
		do {
			let pendingReadStatusArticleIDs = try await syncDatabase.selectPendingReadStatusArticleIDs() ?? Set<String>()
			let pendingStarredStatusArticleIDs = try await syncDatabase.selectPendingStarredStatusArticleIDs() ?? Set<String>()
			
			await delete(recordKeys: deleted, pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs)
			try await update(records: changed,
							 pendingReadStatusArticleIDs: pendingReadStatusArticleIDs,
							 pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs)
		} catch {
			Self.logger.error("CloudKit: Error getting sync status records: \(error.localizedDescription)")
			throw CloudKitZoneError.unknown
		}
	}
}

private extension CloudKitArticlesZoneDelegate {

	func delete(recordKeys: [CloudKitRecordKey], pendingStarredStatusArticleIDs: Set<String>) async {
		let receivedRecordIDs = recordKeys.filter({ $0.recordType == CloudKitArticlesZone.CloudKitArticleStatus.recordType }).map({ $0.recordID })
		let receivedArticleIDs = Set(receivedRecordIDs.map({ stripPrefix($0.externalID) }))
		let deletableArticleIDs = receivedArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		guard !deletableArticleIDs.isEmpty else {
			return
		}

		try? await syncDatabase.deleteSelectedForProcessing(deletableArticleIDs)
		try? await account?.delete(articleIDs: deletableArticleIDs)
	}

	func update(records: [CKRecord], pendingReadStatusArticleIDs: Set<String>, pendingStarredStatusArticleIDs: Set<String>) async throws {

		let receivedUnreadArticleIDs = Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "0" }).map({ stripPrefix($0.externalID) }))
		let receivedReadArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "1" }).map({ stripPrefix($0.externalID) }))
		let receivedUnstarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "0" }).map({ stripPrefix($0.externalID) }))
		let receivedStarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "1" }).map({ stripPrefix($0.externalID) }))

		let updateableUnreadArticleIDs = receivedUnreadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableReadArticleIDs = receivedReadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableUnstarredArticleIDs = receivedUnstarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)
		let updateableStarredArticleIDs = receivedStarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		// Parse items on background thread
		let feedIDsAndItems = await Task.detached(priority: .userInitiated) {
			let parsedItems = records.compactMap { self.makeParsedItem($0) }
			return Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
		}.value

		var errorOccurred = false

		await withTaskGroup(of: Void.self) { group in
			group.addTask { @MainActor in
				do {
					try await self.account?.markAsUnread(updateableUnreadArticleIDs)
				} catch {
					errorOccurred = true
					Self.logger.error("CloudKit: Error while storing unread statuses: \(error.localizedDescription)")
				}
			}

			group.addTask { @MainActor in
				do {
					try await self.account?.markAsRead(updateableReadArticleIDs)
				} catch {
					errorOccurred = true
					Self.logger.error("CloudKit: Error while storing read statuses: \(error.localizedDescription)")
				}
			}

			group.addTask { @MainActor in
				do {
					try await self.account?.markAsUnstarred(updateableUnstarredArticleIDs)
				} catch {
					errorOccurred = true
					Self.logger.error("CloudKit: Error while storing unstarred statuses: \(error.localizedDescription)")
				}
			}

			group.addTask { @MainActor in
				do {
					try await self.account?.markAsStarred(updateableStarredArticleIDs)
				} catch {
					errorOccurred = true
					Self.logger.error("CloudKit: Error while storing starred statuses: \(error.localizedDescription)")
				}
			}

			for (feedID, parsedItems) in feedIDsAndItems {
				group.addTask { @MainActor in
					do {
						guard let articleChanges = try await self.account?.update(feedID, with: parsedItems, deleteOlder: false) else {
							return
						}
						guard let deletes = articleChanges.deletedArticles, !deletes.isEmpty else {
							return
						}
						let syncStatuses = Set(deletes.map { SyncStatus(articleID: $0.articleID, key: .deleted, flag: true) })
						try? await self.syncDatabase.insertStatuses(syncStatuses)
					} catch {
						errorOccurred = true
						Self.logger.error("CloudKit: Error while storing starred articles: \(error.localizedDescription)")
					}
				}
			}
		}

		if errorOccurred {
			throw CloudKitZoneError.unknown
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
			let feedURL = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.feedURL] as? String else {
			return nil
		}

		var contentHTML = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.contentHTML] as? String
		if let contentHTMLData = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.contentHTMLData] as? NSData {
			if let decompressedContentHTMLData = try? contentHTMLData.decompressed(using: .lzfse) {
				contentHTML = String(data: decompressedContentHTMLData as Data, encoding: .utf8)
			}
		}

		var contentText = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.contentText] as? String
		if let contentTextData = articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.contentTextData] as? NSData {
			if let decompressedContentTextData = try? contentTextData.decompressed(using: .lzfse) {
				contentText = String(data: decompressedContentTextData as Data, encoding: .utf8)
			}
		}

		let parsedItem = ParsedItem(syncServiceID: nil,
									uniqueID: uniqueID,
									feedURL: feedURL,
									url: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.url] as? String,
									externalURL: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.externalURL] as? String,
									title: articleRecord[CloudKitArticlesZone.CloudKitArticle.Fields.title] as? String,
									language: nil,
									contentHTML: contentHTML,
									contentText: contentText,
									markdown: nil,
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
