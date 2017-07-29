//
//  TagsManager.swift
//  Database
//
//  Created by Brent Simmons on 7/8/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

// Tags — and the non-existence of tags — are cached, once fetched, for the lifetime of the run.
// This uses some extra memory but cuts way down on the amount of database time spent
// maintaining the tags table.

typealias TagNameSet = Set<String>

final class TagsTable: DatabaseTable {

	let name: String

	private var articleIDCache = [String: TagNameSet]() // articleID: tags
	private var articleIDsWithNoTags = TagNameSet()

	init(name: String) {

		self.name = name
	}

	func saveTagsForArticles(_ articles: Set<Article>) {

		var articlesToSaveTags = Set<Article>()
		var articlesToRemoveTags = Set<Article>()

		articles.forEach { (oneArticle) in

			if articleTagsMatchCache(oneArticle) {
				return
			}
			if let tags = oneArticle.tags {
				articlesToSaveTags.insert(oneArticle)
			}
			else {
				articlesToRemoveTags.insert(oneArticle)
			}
		}

		if !articlesToSaveTags.isEmpty {
			updateTagsForArticles(articlesToSaveTags)
		}

		if !articlesToRemoveTags.isEmpty {
			removeArticleFromTags(articlesToRemoveTags)
		}
	}
}

private extension TagsManager {

	func cacheTagsForArticle(_ article: Article, tags: TagNameSet) {

		articleIDsWithNoTags.remove(article.articleID)
		articleIDCache[article.articleID] = tags
	}

	func cachedTagsForArticleID(_ articleID: String) -> TagNameSet? {

		return articleIDsCache[articleID]
	}

	func articleTagsMatchCache(_ article: Article) -> Bool {

		if let tags = article.tags {
			return tags == articleIDCache[article.articleID]
		}
		return articleIDIsKnowToHaveNoTags(article.articleID)
	}

	func articleIDIsKnownToHaveNoTags(_ articleID: String) -> Bool {

		return articleIDsWithNoTags.contains(articleID)
	}

	func removeTagsFromCacheForArticleID(_ articleID: String) {

		articleIDsCache[oneArticleID] = nil
		articleIDsWithNoTags.insert(oneArticleID)
	}

	func removeArticleFromTags(_ articles: Set<Article>) {

		var articleIDsToRemove = [String]()

		articles.forEach { (oneArticle) in
			let oneArticleID = oneArticle.articleID
			if articleIDIsKnownToHaveNoTags(oneArticle) {
				return
			}
			articleIDsToRemove += oneArticleID
			removeTagsFromCacheForArticleID(oneArticleID)
		}

		if !articleIDsToRemove.isEmpty {
			queue.update { (database) in
				database.rs_deleteRowsWhereKey(DatabaseKey.articleID, inValues: articleIDsToRemove, tableName: DatabaseTableName.tags)
			}
		}
	}

	typealias TagsTable = [String: TagNameSet] // [articleID: Set<tagName>]

	func updateTagsForArticles(_ articles: Set<Article>) {

		var tagsForArticleIDs = TagsTable()
		articles.forEach { (oneArticle)
			if let tags = oneArticle.tags {
				cacheTagsForArticle(oneArticle, tags)
				tagsForArticleIDs[oneArticle.articleID] = oneArticle.tags
			}
			else {
				assertionFailure("article must have tags")
			}
		}

		if tagsForArticleIDs.isEmpty { // Shouldn’t be empty
			return
		}
		let articleIDs = tagsForArticleIDs.keys
		
		queue.update { (database) in

			let existingTags = self.fetchTagsForArticleIDs(articleIDs, database: database)
			self.syncIncomingAndExistingTags(incomingTags: tagsForArticleIDs, existingTags: existingTags, database: database)
		}
	}

	func syncIncomingAndExistingTags(incomingTags: TagsTable, existingTags: TagsTable, database: database) {

		for (oneArticleID, oneTagNames) in incomingTags {
			if let existingTagNames = existingTags[oneArticleID] {
				syncIncomingAndExistingTagsForArticleID(oneArticleID, incomingTagNames: oneTagNames, existingTagNames: existingTagNames, database: database)
			}
			else {
				saveIncomingTagsForArticleID(oneArticleID, tagNames: oneTagNames, database: database)
			}
		}
	}

	func saveIncomingTagsForArticleID(_ articleID: String, tagNames: TagNameSet, database: FMDatabase) {

		// No existing tags in database. Simple save.

		for oneTagName in tagNames {
			let oneDictionary = [DatabaseTableName.articleID: articleID, DatabaseTableName.tagName: oneTagName]
			database.rs_insertRow(with: oneDictionary, insertType: .OrIgnore, tableName: DatabaseTableName.tags)
		}
	}

	func syncingIncomingAndExistingTagsForArticleID(_ articleID: String, incomingTagNames: TagNameSet, existingTagNames: TagNameSet, database: FMDatabase) {

		if incomingTagNames == existingTagNames {
			return
		}

		var tagsToRemove = TagNameSet()
		for oneExistingTagName in existingTagNames {
			if !incomingTagNames.contains(oneExistingTagName) {
				tagsToRemove.insert(oneExistingTagName)
			}
		}

		var tagsToAdd = TagNameSet()
		for oneIncomingTagName in incomingTagNames {
			if !existingTagNames.contains(oneIncomingTagName) {
				tagsToAdd.insert(oneIncomingTagName)
			}
		}

		if !tagsToRemove.isEmpty {
			let placeholders = NSString.rs_SQLValueListWithPlaceholders
			let sql = "delete from \(DatabaseTableName.tags) where \(DatabaseKey.articleID) = ? and \(DatabaseKey.tagName) in "
			database.executeUpdate(sql, withArgumentsIn: [articleID, ])
		}
	}

	func fetchTagsForArticleIDs(_ articleIDs: Set<String>, database: FMDatabase) -> TagsTable {

		var tagSpecifiers = TagsTable()

		guard let rs = database.rs_selectRowsWhereKey(DatabaseKey.articleID, inValues: Array(articleIDs), tableName: DatabaseTableName.tags) else {
			return tagSpecifiers
		}

		while rs.next() {

			guard let oneTagName = rs.string(forColumn: DatabaseKey.tagName), let oneArticleID = rs.string(forColumn: DatabaseKey.articleID) else {
				continue
			}
			if tagSpecifiers[oneArticleID] == nil {
				tagSpecifiers[oneArticleID] = Set([oneTagName])
			}
			else {
				tagSpecifiers[oneArticleID]!.insert(oneTagName)
			}
		}

		return tagSpecifiers
	}
}

