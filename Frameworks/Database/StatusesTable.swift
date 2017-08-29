//
//  StatusesTable.swift
//  Evergreen
//
//  Created by Brent Simmons on 5/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import Data

// Article->ArticleStatus is a to-one relationship.
//
// CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0, accountInfo BLOB);

final class StatusesTable: DatabaseTable {

	let name: String
	let databaseIDKey = DatabaseKey.articleID
	private let cache = DatabaseObjectCache()

	init(name: String) {

		self.name = name
	}

	// Mark: DatabaseTable Methods
	
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
		
		if let status = statusWithRow(row) {
			return status as DatabaseObject
		}
		return nil
	}

	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		
		// TODO
	}

	// MARK: Fetching

	func statusWithRow(_ row: FMResultSet) -> ArticleStatus? {

		guard let articleID = row.string(forColumn: DatabaseKey.articleID) else {
			return nil
		}
		if let cachedStatus = cache[articleID] as? ArticleStatus {
			return cachedStatus
		}

		guard let dateArrived = row.date(forColumn: DatabaseKey.dateArrived) else {
			return nil
		}

		let articleStatus = ArticleStatus(articleID: articleID, dateArrived: dateArrived, row: row)
		cache[articleID] = articleStatus
		return articleStatus
	}
	
	// MARK: Creating

	func ensureStatusesForArticles(_ articles: Set<Article>, _ database: FMDatabase) {

		let articlesNeedingStatuses = articles.missingStatuses()
		if articlesNeedingStatuses.isEmpty {
			return
		}

		createAndSaveStatusesForArticles(articlesNeedingStatuses, database)

		attachCachedStatuses(articlesNeedingStatuses)
		assert(articles.eachHasAStatus())
	}
	
	// MARK: Marking
	
	func markArticleIDs(_ articleIDs: Set<String>, _ statusKey: String, _ flag: Bool, _ database: FMDatabase) {
		
		updateRowsWithValue(NSNumber(value: flag), valueKey: statusKey, whereKey: DatabaseKey.articleID, matches: Array(articleIDs), database: database)
	}

	// MARK: Updating
	
	

//	func attachStatuses(_ articles: Set<Article>, _ database: FMDatabase) {
//
//		// Look in cache first.
//		attachCachedStatuses(articles)
//		let articlesNeedingStatuses = articlesMissingStatuses(articles)
//		if articlesNeedingStatuses.isEmpty {
//			return
//		}
//
//		// Fetch from database.
//		fetchAndCacheStatusesForArticles(articlesNeedingStatuses, database)
//		attachCachedStatuses(articlesNeedingStatuses)
//
//		// Create new statuses, and cache and save them in the database.
//		// It shouldn’t happen that an Article in the database has no corresponding ArticleStatus,
//		// but the case should be handled anyway.
//
//		let articlesNeedingStatusesCreated = articlesMissingStatuses(articlesNeedingStatuses)
//		if articlesNeedingStatusesCreated.isEmpty {
//			return
//		}
//		createAndSaveStatusesForArticles(articlesNeedingStatusesCreated, database)
//
//		assertNoMissingStatuses(articles)
//	}


//	func ensureStatusesForParsedArticles(_ parsedArticles: [ParsedItem], _ callback: @escaping RSVoidCompletionBlock) {
//
//		// 1. Check cache for statuses
//		// 2. Fetch statuses not found in cache
//		// 3. Create, save, and cache statuses not found in database
//
//		var articleIDs = Set(parsedArticles.map { $0.articleID })
//		articleIDs = articleIDsMissingStatuses(articleIDs)
//		if articleIDs.isEmpty {
//			callback()
//			return
//		}
//
//		queue.fetch { (database: FMDatabase!) -> Void in
//
//			let statuses = self.fetchStatusesForArticleIDs(articleIDs, database: database)
//
//			DispatchQueue.main.async {
//
//				self.cache.addObjectsNotCached(Array(statuses))
//
//				let newArticleIDs = self.articleIDsMissingStatuses(articleIDs)
//				if !newArticleIDs.isEmpty {
//					self.createAndSaveStatusesForArticleIDs(newArticleIDs)
//				}
//
//				callback()
//			}
//		}
//	}
}

private extension StatusesTable {

	func attachCachedStatuses(_ articles: Set<Article>) {

		for article in articles {
			if let cachedStatus = cache[article.articleID] as? ArticleStatus {
				article.status = cachedStatus
			}
		}
	}

	// MARK: Fetching

//	func fetchAndCacheStatusesForArticles(_ articles: Set<Article>, _ database: FMDatabase) {
//
//		fetchAndCacheStatusesForArticleIDs(articles.articleIDs(), database)
//	}
//
//	func fetchAndCacheStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {
//
//		if let statuses = fetchStatusesForArticleIDs(articleIDs, database) {
//			cache.addObjectsNotCached(Array(statuses))
//		}
//	}
//
//	func fetchStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) -> Set<ArticleStatus>? {
//
//		guard let resultSet = selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) else {
//			return nil
//		}
//		return articleStatusesWithResultSet(resultSet)
//	}
//
//	func articleStatusesWithResultSet(_ resultSet: FMResultSet) -> Set<ArticleStatus> {
//
//		return resultSet.mapToSet(articleStatusWithRow)
//	}
//
//	func articleStatusWithRow(_ row: FMResultSet) -> ArticleStatus? {
//
//		guard let articleID = row.string(forColumn: DatabaseKey.articleID) else {
//			return nil
//		}
//		if let cachedStatus = cache[articleID] {
//			return cachedStatus
//		}
//		let status = ArticleStatus(articleID: articleID, row: row)
//		cache[articleID] = status
//		return status
//	}
	
	// MARK: Creating

	func saveStatuses(_ statuses: Set<ArticleStatus>, _ database: FMDatabase) {

		let statusArray = statuses.map { $0.databaseDictionary() }
		insertRows(statusArray, insertType: .orIgnore, in: database)
	}

	func createAndSaveStatusesForArticles(_ articles: Set<Article>, _ database: FMDatabase) {

		let articleIDs = Set(articles.map { $0.articleID })
		createAndSaveStatusesForArticleIDs(articleIDs, database)
	}

	func createAndSaveStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {

		let now = Date()
		let statuses = articleIDs.map { ArticleStatus(articleID: $0, dateArrived: now) }
		let databaseObjects = statuses.map { $0 as DatabaseObject }
		cache.addObjectsNotCached(databaseObjects)

		saveStatuses(Set(statuses), database)
	}

	// MARK: Utilities

//	func articleIDsMissingCachedStatuses(_ articleIDs: Set<String>) -> Set<String> {
//
//		return Set(articleIDs.filter { !cache.objectWithIDIsCached($0) })
//	}
//
//	func articlesMissingStatuses(_ articles: Set<Article>) -> Set<Article> {
//
//		return articles.withNilProperty(\Article.status)
//	}
}

//extension ParsedItem {
//
//	var articleID: String {
//		get {
//			return "\(feedURL) \(uniqueID)" //Must be same as Article.articleID
//		}
//	}
//}

