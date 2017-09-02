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

	let name = DatabaseTableName.statuses
	private let cache = DatabaseObjectCache()

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
}

private extension StatusesTable {

	func attachCachedStatuses(_ articles: Set<Article>) {

		for article in articles {
			if let cachedStatus = cache[article.articleID] as? ArticleStatus {
				article.status = cachedStatus
			}
		}
	}

	// MARK: Creating

	func saveStatuses(_ statuses: Set<ArticleStatus>, _ database: FMDatabase) {

		let statusArray = statuses.map { $0.databaseDictionary() }
		insertRows(statusArray, insertType: .orIgnore, in: database)
	}

	func cacheStatuses(_ statuses: [ArticleStatus]) {

		let databaseObjects = statuses.map { $0 as DatabaseObject }
		cache.addObjectsNotCached(databaseObjects)
	}

	func createAndSaveStatusesForArticles(_ articles: Set<Article>, _ database: FMDatabase) {

		let articleIDs = Set(articles.map { $0.articleID })
		createAndSaveStatusesForArticleIDs(articleIDs, database)
	}

	func createAndSaveStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {

		let now = Date()
		let statuses = articleIDs.map { ArticleStatus(articleID: $0, dateArrived: now) }

		cacheStatuses(statuses)
		saveStatuses(Set(statuses), database)
	}

}
