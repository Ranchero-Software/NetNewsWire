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
	private let cache = StatusCache()

	func existingStatus(for articleID: String) -> ArticleStatus? {

		cache.lock()
		defer { cache.unlock() }
		return cache[articleID]
	}

	// MARK: Creating/Updating

	func ensureStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {

		cache.lock()
		defer { cache.unlock() }

		// Check cache.
		let articleIDsMissingCachedStatus = articleIDsWithNoCachedStatus(articleIDs)
		if articleIDsMissingCachedStatus.isEmpty {
			return
		}

		// Check database.
		fetchAndCacheStatusesForArticleIDs(articleIDsMissingCachedStatus, database)
		let articleIDsNeedingStatus = articleIDsWithNoCachedStatus(articleIDs)
		if articleIDsNeedingStatus.isEmpty {
			return
		}

		// Create new statuses.
		createAndSaveStatusesForArticleIDs(articleIDsNeedingStatus, database)
	}

	// MARK: Marking
	
	func markArticleIDs(_ articleIDs: Set<String>, _ statusKey: String, _ flag: Bool, _ database: FMDatabase) {
		
		cache.lock()
		defer { cache.unlock() }

		// TODO: replace statuses in cache.

		updateRowsWithValue(NSNumber(value: flag), valueKey: statusKey, whereKey: DatabaseKey.articleID, matches: Array(articleIDs), database: database)
	}
}

// MARK: - Private

private extension StatusesTable {

	// MARK: Fetching

	func fetchStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) -> [String: ArticleStatus] {

		// Does not create statuses. Checks cache first, then database only if needed.

		var d = [String: ArticleStatus]()
		var articleIDsMissingCachedStatus = Set<String>()

		for articleID in articleIDs {
			if let cachedStatus = cache[articleID] as? ArticleStatus {
				d[articleID] = cachedStatus
			}
			else {
				articleIDsMissingCachedStatus.insert(articleID)
			}
		}

		if articleIDsMissingCachedStatus.isEmpty {
			return d
		}

		fetchAndCacheStatusesForArticleIDs(articleIDsMissingCachedStatus, database)
		for articleID in articleIDsMissingCachedStatus {
			if let cachedStatus = cache[articleID] as? ArticleStatus {
				d[articleID] = cachedStatus
			}
		}

		return d
	}

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

	func articleIDsWithNoCachedStatus(_ articleIDs: Set<String>) -> Set<String> {

		return Set(articleIDs.filter { cache[$0] == nil })
	}

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
		let statuses = Set(articleIDs.map { ArticleStatus(articleID: $0, dateArrived: now) })

		cache.add(statuses)

		saveStatuses(statuses, database)
	}

	func fetchAndCacheStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {

		guard let resultSet = selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) else {
			return
		}

		let statuses = resultSet.mapToSet(statusWithRow)
		cache.add(statuses)
	}
}

private final class StatusCache {

	// Locking is left to the caller. Use the provided lock methods.

	private let lock = NSLock()
	private var isLocked = false
	var dictionary = [String: ArticleStatus]()

	func lock() {

		assert(!isLocked)
		lock.lock()
		isLocked = true
	}

	func unlock() {

		assert(isLocked)
		lock.unlock()
		isLocked = false
	}

	func add(_ statuses: Set<ArticleStatus>) {

		// Replaces any cached statuses.

		assert(isLocked)
		for status in statuses {
			self[status.articleID] = status
		}
	}

	func statuses(for articleIDs: Set<String>) -> [String: ArticleStatus] {

		assert(isLocked)

		var d = [String: ArticleStatus]()
		for articleID in articleIDs {
			if let cachedStatus = self[articleID] {
				d[articleID] = cachedStatus
			}
		}

		return d
	}

	subscript(_ articleID: String) -> ArticleStatus {
		get {
			assert(isLocked)
			return self[articleID]
		}
		set {
			assert(isLocked)
			self[articleID] = newValue
		}
	}
}


