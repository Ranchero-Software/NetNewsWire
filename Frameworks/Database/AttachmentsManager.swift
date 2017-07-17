//
//  AttachmentsManager.swift
//  Database
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

// Attachments are treated as atomic.
// If an attachment in a feed changes any of its values,
// it’s actually saved as a new attachment and the old one is deleted.
// (This is rare compared to an article in a feed changing its text, for instance.)
//
// Article -> Attachment is one-to-many.
// Attachment -> Article is one-to-one.
// A given attachment can be owned by one and only one Article.
// An attachment with the same exact values (except for articleID) might exist.
// (That would be quite rare. But it’s by design.)
//
// All the functions here must be called only from inside the database serial queue.
// (The serial queue makes locking unnecessary.)
//
// Attachments are cached, for the lifetime of the app run, once fetched or saved.
// Because:
// * They don’t take up much space.
// * It seriously cuts down on the number of database reads and writes.

final class AttachmentsManager {

	private var cachedAttachments = [String: Attachment]() // Attachment.databaseID key
	private var cachedAttachmentsByArticle = [String: Set<Attachment>]() // Article.databaseID key
	private var articlesWithNoAttachments = Set<String>() // Article.databaseID
	private let table = DatabaseTable(name: DatabaseTableName.attachments)

	func fetchAttachmentsForArticles(_ articles: Set<Article>, database: FMDatabase) {

	}

	func saveAttachmentsForArticles(_ articles: Set<Article>, database: FMDatabase) {

		// This is complex and overly long because it’s optimized for fewest database hits.

		var articlesWithPossiblyAllAttachmentsDeleted = Set<Article>()
		var attachmentsToSave = Set<Attachment>()
		var attachmentsToDelete = Set<Attachment>()

		func reconcileAttachments(incomingAttachments: Set<Attachment>, existingAttachments: Set<Attachment>) {

			for oneIncomingAttachment in incomingAttachments { // Add some.
				if !existingAttachments.contains(oneIncomingAttachment) {
					attachmentsToSave.insert(oneIncomingAttachment)
				}
			}
			for oneExistingAttachment in existingAttachments { // Delete some.
				if !incomingAttachments.contains(oneExistingAttachment) {
					attachmentsToDelete.insert(oneExistingAttachment)
				}
			}
		}

		for oneArticle in articles {

			if let oneAttachments = oneArticle.attachments, !oneAttachments.isEmpty {

				// If it matches the cache, then do nothing.
				if let oneCachedAttachments = cachedAttachmentsByArticle(oneArticle.databaseID) {
					if oneCachedAttachments == oneAttachments {
						continue
					}

					// There is a cache and it doesn’t match.
					reconcileAttachments(incomingAttachments: oneAttachments, existingAttachments: oneCachedAttachments)
				}

				else { // no cache, but article has attachments

					if let resultSet = table.selectRowsWhere(key: DatabaseKey.articleID, equals: oneArticle.databaseID, in: database) {
						let existingAttachments = attachmentsWithResultSet(resultSet)
						if existingAttachments != oneAttachments { // Don’t match?
							reconcileAttachments(incomingAttachments: oneAttachments, existingAttachments: existingAttachments)
						}
					}
					else {
						// Nothing in database. Just save.
						attachmentsToSave.formUnion(oneAttachments)
					}
				}

				cacheAttachmentsForArticle(oneArticle)
			}
			else {
				// No attachments: might need to delete them all from database
				if !articlesWithNoAttachments.contains(oneArticle.databaseID) {
					articlesWithPossiblyAllAttachmentsDeleted.insert(oneArticle)
					uncacheAttachmentsForArticle(oneArticle)
				}
			}
		}

		if !articlesWithPossiblyAllAttachmentsDeleted.isEmpty {
			deleteAttachmentsForArticles(articlesWithPossiblyAllAttachmentsDeleted)
		}
	}
}

private extension AttachmentsManager {

	func deleteAttachmentsForArticles(_ articles: Set<Article>, database: FMDatabase) {

		let articleIDs = articles.map { $0.databaseID }
		articlesWithNoAttachments.formUnion(Set(articleIDs))
		articleIDs.forEach { cachedAttachmentsByArticle[$0] = nil }

		let _ = database.rs_deleteRowsWhereKey(DatabaseKey.articleID, inValues: articleIDs, tableName: DatabaseTableName.attachments)
	}

	func addCachedAttachmentsToArticle(_ article: Article) {

		if let _ = article.attachments {
			return
		}

		if let attachments = cachedAttachmentsByArticle[article.databaseID] {
			article.attachments = attachments
		}
	}

	func fetchAttachmentsForArticle(_ article: Article, database: FMDatabase) {

		if articlesWithNoAttachments.contains(article.databaseID) {
			return
		}
		addCachedAttachmentsToArticle(article)
		if let _ = article.attachments {
			return
		}




	}

	func uncacheAttachmentsForArticle(_ article: Article) {

		assert(article.attachments == nil || article.attachments.isEmpty)
		articlesWithNoAttachments.insert(article.databaseID)
		cachedAttachmentsByArticle[article.databaseID] = nil

		var attachmentDatabaseIDsToUncache = Set<String>()
		for (databaseID, attachment) in cachedAttachments {
			if attachment.articleID == article.databaseID {
				attachmentDatabaseIDsToUncache.insert(databaseID)
			}
		}
		attachmentDatabaseIDsToUncache.forEach { uncacheAttachmentWithDatabaseID($0) }
	}

	func cacheAttachmentsForArticle(_ article: Article) {

		guard let attachments = article.attachments, !attachments.isEmpty else {
			assertionFailure("article.attachments must not be empty")
		}

		articlesWithNoAttachments.remove(article.databaseID)
		cachedAttachmentsByArticle[article.databaseID] = attachments
		cacheAttachment(attachments)
	}

	func cachedAttachmentForDatabaseID(_ databaseID: String) -> Attachment? {

		return cachedAttachments[databaseID]
	}

	func cacheAttachments(_ attachments: Set<Attachment>) {

		attachments.forEach { cacheAttachment($) }
	}

	func cacheAttachment(_ attachment: Attachment) {

		cachedAttachments[attachment.databaseID] = attachment
	}

	func uncacheAttachmentWithDatabaseID(_ databaseID: String) {

		cachedAttachments[databaseID] = nil
	}

	func saveAttachmentsForArticle(_ article: Article, database: FMDatabase) {

		if let attachments = article.attachments {

		}
		else {
			if articlesWithNoAttachments.contains(article.databaseID) {
				return
			}
			
			articlesWithNoAttachments.insert(article.databaseID)
			cachedAttachmentsByArticle[article.databaseID] = nil

			deleteAttachmentsForArticleID(article.databaseID)
		}

	}

	func attachmentsWithResultSet(_ resultSet: FMResultSet) -> Set<Attachment> {

		var attachments = Set<Attachment>()

		while (resultSet.next()) {
			if let oneAttachment = attachmentWithRow(resultSet) {
				attachments.insert(oneAttachment)
			}
		}

		return attachments
	}

	func attachmentWithRow(_ row: FMResultSet) -> Attachment? {

		let databaseID = row.string(forColumn: DatabaseKey.databaseID)
		if let cachedAttachment = cachedAttachmentForDatabaseID(databaseID) {
			return cachedAttachment
		}

		return Attachment(databaseID: databaseID, row: row)
	}
}
