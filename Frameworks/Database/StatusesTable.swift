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
	private let queue: RSDatabaseQueue
	
	init(queue: RSDatabaseQueue) {
		
		self.queue = queue
	}
	
	func cachedStatus(for articleID: String) -> ArticleStatus? {

		assert(Thread.isMainThread)
		assert(cache[articleID] != nil)
		return cache[articleID]
	}

	// MARK: Creating/Updating

	func ensureStatusesForArticleIDs(_ articleIDs: Set<String>, _ completion: @escaping RSVoidCompletionBlock) {
		
		// Adds them to the cache if not cached.
		
		assert(Thread.isMainThread)
		
		// Check cache.
		let articleIDsMissingCachedStatus = articleIDsWithNoCachedStatus(articleIDs)
		if articleIDsMissingCachedStatus.isEmpty {
			completion()
			return
		}
		
		// Check database.
		fetchAndCacheStatusesForArticleIDs(articleIDsMissingCachedStatus) {
			
			let articleIDsNeedingStatus = articleIDsWithNoCachedStatus(articleIDs)
			if articleIDsNeedingStatus.isEmpty {
				completion()
				return
			}
			
			// Create new statuses.
			createAndSaveStatusesForArticleIDs(articleIDsNeedingStatus, completion)
		}
	}

	// MARK: Marking
	
	func markArticleIDs(_ articleIDs: Set<String>, _ statusKey: String, _ flag: Bool, _ database: FMDatabase) {
		
		// TODO: replace statuses in cache.

		updateRowsWithValue(NSNumber(value: flag), valueKey: statusKey, whereKey: DatabaseKey.articleID, matches: Array(articleIDs), database: database)
	}
}

// MARK: - Private

private extension StatusesTable {

	// MARK: Fetching

	func statusWithRow(_ row: FMResultSet) -> ArticleStatus? {

		guard let articleID = row.string(forColumn: DatabaseKey.articleID) else {
			return nil
		}
		guard let dateArrived = row.date(forColumn: DatabaseKey.dateArrived) else {
			return nil
		}

		let articleStatus = ArticleStatus(articleID: articleID, dateArrived: dateArrived, row: row)
		return articleStatus
	}

	// MARK: Cache
	
	func articleIDsWithNoCachedStatus(_ articleIDs: Set<String>) -> Set<String> {

		return Set(articleIDs.filter { cache[$0] == nil })
	}

	// MARK: Creating

	func saveStatuses(_ statuses: Set<ArticleStatus>) {

		queue.update { (database) in
			let statusArray = statuses.map { $0.databaseDictionary() }
			insertRows(statusArray, insertType: .orIgnore, in: database)
		}
	}

	func createAndSaveStatusesForArticleIDs(_ articleIDs: Set<String>, _ completion: @escaping RSVoidCompletionBlock) {

		assert(Thread.isMainThread)
		
		let now = Date()
		let statuses = Set(articleIDs.map { ArticleStatus(articleID: $0, dateArrived: now) })
		cache.addIfNotCached(statuses)
		
		// No need to wait for database to return before calling completion,
		// since the new statuses have been cached at this point.
		
		completion()
		saveStatuses(statuses)
	}

	func fetchAndCacheStatusesForArticleIDs(_ articleIDs: Set<String>, _ completion: @escaping RSVoidCompletionBlock) {
		
		queue.fetch { (database) in
			guard let resultSet = selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) else {
				completion()
				return
			}
			
			let statuses = resultSet.mapToSet(statusWithRow)
			
			DispatchQueue.main.async {
				cache.addIfNotCached(statuses)
				completion()
			}
		}
	}
}

private final class StatusCache {

	// Main thread only.

	var dictionary = [String: ArticleStatus]()

	func add(_ statuses: Set<ArticleStatus>) {

		// Replaces any cached statuses.

		for status in statuses {
			self[status.articleID] = status
		}
	}

	func addIfNotCached(_ statuses: Set<ArticleStatus>) {
		
		// Does not replace already cached statuses.
		
		for status in statuses {
			let articleID = status.articleID
			if let _ = self[articleID] {
				continue
			}
			self[articleID] = status
		}
	}
	
	subscript(_ articleID: String) -> ArticleStatus {
		get {
			return self[articleID]
		}
		set {
			self[articleID] = newValue
		}
	}
}


