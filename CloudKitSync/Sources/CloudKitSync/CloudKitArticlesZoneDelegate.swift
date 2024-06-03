//
//  CloudKitArticlesZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Parser
import Web
import CloudKit
import SyncDatabase
import Articles
import ArticlesDatabase
import Database

public final class CloudKitArticlesZoneDelegate: CloudKitZoneDelegate {

	public struct ArticleSupport {

		let delete: (Set<String>) -> Void
		let markRead: (Set<String>) -> Void
		let markUnread: (Set<String>) -> Void
		let markStarred: (Set<String>) -> Void
		let markUnstarred: (Set<String>) -> Void
		let update: (String, Set<ParsedItem>, Bool) async throws -> ArticleChanges? // feedID, parsedItems, deleteOlder

		public init(delete: @escaping (Set<String>) -> Void, markRead: @escaping (Set<String>) -> Void, markUnread: @escaping (Set<String>) -> Void, markStarred: @escaping (Set<String>) -> Void, markUnstarred: @escaping (Set<String>) -> Void, update: @escaping (String, Set<ParsedItem>, Bool) async throws -> ArticleChanges?) {
			self.delete = delete
			self.markRead = markRead
			self.markUnread = markUnread
			self.markStarred = markStarred
			self.markUnstarred = markUnstarred
			self.update = update
		}
	}

	let articleSupport: ArticleSupport
	let database: SyncDatabase
	weak var articlesZone: CloudKitArticlesZone?

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	public init(articleSupport: ArticleSupport, database: SyncDatabase, articlesZone: CloudKitArticlesZone) {
		self.articleSupport = articleSupport
		self.database = database
		self.articlesZone = articlesZone
	}

	public func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {

		Task { @MainActor in
			do {

				let pendingReadStatusArticleIDs = (try await self.database.selectPendingReadStatusArticleIDs()) ?? Set<String>()
				let pendingStarredStatusArticleIDs = (try await self.database.selectPendingStarredStatusArticleIDs()) ?? Set<String>()

				await self.delete(recordKeys: deleted, pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs)

				try await self.update(records: changed,
							pendingReadStatusArticleIDs: pendingReadStatusArticleIDs,
							pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs)
				completion(.success(()))

			} catch {
				os_log(.error, log: self.log, "Error in CloudKitArticlesZoneDelegate.cloudKitDidModify: %@", error.localizedDescription)
				completion(.failure(CloudKitZoneError.unknown))
			}
		}
	}
}

private extension CloudKitArticlesZoneDelegate {

	@MainActor func delete(recordKeys: [CloudKitRecordKey], pendingStarredStatusArticleIDs: Set<String>) async {

		let receivedRecordIDs = recordKeys.filter({ $0.recordType == CloudKitArticlesZone.CloudKitArticleStatus.recordType }).map({ $0.recordID })
		let receivedArticleIDs = Set(receivedRecordIDs.map({ stripPrefix($0.externalID) }))
		let deletableArticleIDs = receivedArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		guard !deletableArticleIDs.isEmpty else {
			return
		}

		try? await database.deleteSelectedForProcessing(deletableArticleIDs)
		articleSupport.delete(deletableArticleIDs)
	}

	@MainActor private func update(records: [CKRecord], pendingReadStatusArticleIDs: Set<String>, pendingStarredStatusArticleIDs: Set<String>) async throws {

		let receivedUnreadArticleIDs = Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "0" }).map({ stripPrefix($0.externalID) }))
		let receivedReadArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "1" }).map({ stripPrefix($0.externalID) }))
		let receivedUnstarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "0" }).map({ stripPrefix($0.externalID) }))
		let receivedStarredArticleIDs =  Set(records.filter({ $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "1" }).map({ stripPrefix($0.externalID) }))

		let updateableUnreadArticleIDs = receivedUnreadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableReadArticleIDs = receivedReadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableUnstarredArticleIDs = receivedUnstarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)
		let updateableStarredArticleIDs = receivedStarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		var errorOccurred = false

		articleSupport.markRead(updateableReadArticleIDs)
		articleSupport.markUnread(updateableUnreadArticleIDs)
		
		articleSupport.markStarred(updateableStarredArticleIDs)
		articleSupport.markUnstarred(updateableUnstarredArticleIDs)

		let parsedItems = await Self.makeParsedItems(records)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }

		for (feedID, parsedItems) in feedIDsAndItems {

			do {
				let articleChanges = try await articleSupport.update(feedID, parsedItems, false)
				guard let deletes = articleChanges?.deletedArticles, !deletes.isEmpty else {
					continue
				}

				let syncStatuses = deletes.map { SyncStatus(articleID: $0.articleID, key: .deleted, flag: true) }
				try? await self.database.insertStatuses(Set(syncStatuses))

			} catch {
				errorOccurred = true
				os_log(.error, log: self.log, "Error occurred while storing articles: %@", error.localizedDescription)
			}
		}

		if errorOccurred {
			throw CloudKitZoneError.unknown
		}
	}

	func stripPrefix(_ externalID: String) -> String {
		return String(externalID[externalID.index(externalID.startIndex, offsetBy: 2)..<externalID.endIndex])
	}

	private static func makeParsedItems(_ articleRecords: [CKRecord]) async -> Set<ParsedItem> {

		let task = Task.detached { () -> Set<ParsedItem> in
			let parsedItems = articleRecords.compactMap { makeParsedItem($0) }
			return Set(parsedItems)
		}

		return await task.value
	}

	static func makeParsedItem(_ articleRecord: CKRecord) -> ParsedItem? {
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
