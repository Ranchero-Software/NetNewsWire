//
//  StatusesTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import Articles

// Article->ArticleStatus is a to-one relationship.
//
// CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

final class StatusesTable: DatabaseTable {

	let name = DatabaseTableName.statuses
	private let cache = StatusCache()
	private let queue: DatabaseQueue
	
	init(queue: DatabaseQueue) {
		self.queue = queue
	}

	// MARK: - Creating/Updating

	func ensureStatusesForArticleIDs(_ articleIDs: Set<String>, _ read: Bool, _ database: FMDatabase) -> [String: ArticleStatus] {
		// Check cache.
		let articleIDsMissingCachedStatus = articleIDsWithNoCachedStatus(articleIDs)
		if articleIDsMissingCachedStatus.isEmpty {
			return statusesDictionary(articleIDs)
		}
		
		// Check database.
		fetchAndCacheStatusesForArticleIDs(articleIDsMissingCachedStatus, database)
			
		let articleIDsNeedingStatus = self.articleIDsWithNoCachedStatus(articleIDs)
		if !articleIDsNeedingStatus.isEmpty {
			// Create new statuses.
			self.createAndSaveStatusesForArticleIDs(articleIDsNeedingStatus, read, database)
		}
			
		return statusesDictionary(articleIDs)
	}

	func existingStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) -> [String: ArticleStatus] {
		// Check cache.
		let articleIDsMissingCachedStatus = articleIDsWithNoCachedStatus(articleIDs)
		if articleIDsMissingCachedStatus.isEmpty {
			return statusesDictionary(articleIDs)
		}

		// Check database.
		fetchAndCacheStatusesForArticleIDs(articleIDsMissingCachedStatus, database)

		return statusesDictionary(articleIDs)
	}

	// MARK: - Marking

	@discardableResult
	func mark(_ statuses: Set<ArticleStatus>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) -> Set<ArticleStatus>? {
		// Sets flag in both memory and in database.

		var updatedStatuses = Set<ArticleStatus>()

		for status in statuses {
			if status.boolStatus(forKey: statusKey) == flag {
				continue
			}
			status.setBoolStatus(flag, forKey: statusKey)
			updatedStatuses.insert(status)
		}

		if updatedStatuses.isEmpty {
			return nil
		}
		let articleIDs = updatedStatuses.articleIDs()
		
		self.markArticleIDs(articleIDs, statusKey, flag, database)
		
		return updatedStatuses
	}

	// MARK: - Fetching

	func fetchUnreadArticleIDs() -> Set<String> {
		return fetchArticleIDs("select articleID from statuses where read=0 and userDeleted=0;")
	}

	func fetchStarredArticleIDs() -> Set<String> {
		return fetchArticleIDs("select articleID from statuses where starred=1 and userDeleted=0;")
	}
	
	func fetchArticleIDsForStatusesWithoutArticles() -> Set<String> {
		return fetchArticleIDs("select articleID from statuses s where (read=0 or starred=1) and userDeleted=0 and not exists (select 1 from articles a where a.articleID = s.articleID);")
	}
	
	func fetchArticleIDs(_ sql: String) -> Set<String> {
		var articleIDs = Set<String>()
		guard !queue.isSuspended else {
			return articleIDs
		}
		queue.runInDatabaseSync { (database) in
			guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
				return
			}
			articleIDs = resultSet.mapToSet(self.articleIDWithRow)
		}
		return articleIDs
	}
	
	func articleIDWithRow(_ row: FMResultSet) -> String? {
		return row.string(forColumn: DatabaseKey.articleID)
	}
	
	func statusWithRow(_ row: FMResultSet) -> ArticleStatus? {
		guard let articleID = row.string(forColumn: DatabaseKey.articleID) else {
			return nil
		}
		return statusWithRow(row, articleID: articleID)
	}

	func statusWithRow(_ row: FMResultSet, articleID: String) ->ArticleStatus? {
		if let cachedStatus = cache[articleID] {
			return cachedStatus
		}

		guard let dateArrived = row.date(forColumn: DatabaseKey.dateArrived) else {
			return nil
		}

		let articleStatus = ArticleStatus(articleID: articleID, dateArrived: dateArrived, row: row)
		cache.addStatusIfNotCached(articleStatus)

		return articleStatus
	}

	func statusesDictionary(_ articleIDs: Set<String>) -> [String: ArticleStatus] {
		var d = [String: ArticleStatus]()

		for articleID in articleIDs {
			if let articleStatus = cache[articleID] {
				d[articleID] = articleStatus
			}
		}

		return d
	}

	// MARK: - Cleanup

	func removeStatuses(_ articleIDs: Set<String>, _ database: FMDatabase) {
		deleteRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), in: database)
	}
}

// MARK: - Private

private extension StatusesTable {

	// MARK: - Cache
	
	func articleIDsWithNoCachedStatus(_ articleIDs: Set<String>) -> Set<String> {
		return Set(articleIDs.filter { cache[$0] == nil })
	}

	// MARK: - Creating

	func saveStatuses(_ statuses: Set<ArticleStatus>, _ database: FMDatabase) {
		let statusArray = statuses.map { $0.databaseDictionary()! }
		self.insertRows(statusArray, insertType: .orIgnore, in: database)
	}

	func createAndSaveStatusesForArticleIDs(_ articleIDs: Set<String>, _ read: Bool, _ database: FMDatabase) {
		let now = Date()
		let statuses = Set(articleIDs.map { ArticleStatus(articleID: $0, read: read, dateArrived: now) })
		cache.addIfNotCached(statuses)
		
		saveStatuses(statuses, database)
	}

	func fetchAndCacheStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {
		guard let resultSet = self.selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) else {
			return
		}
		
		let statuses = resultSet.mapToSet(self.statusWithRow)
		self.cache.addIfNotCached(statuses)
	}

	// MARK: - Marking

	func markArticleIDs(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) {
		updateRowsWithValue(NSNumber(value: flag), valueKey: statusKey.rawValue, whereKey: DatabaseKey.articleID, matches: Array(articleIDs), database: database)
	}
}

// MARK: -

private final class StatusCache {

	// Serial database queue only.

	var dictionary = [String: ArticleStatus]()
	var cachedStatuses: Set<ArticleStatus> {
		return Set(dictionary.values)
	}

	func add(_ statuses: Set<ArticleStatus>) {
		// Replaces any cached statuses.
		for status in statuses {
			self[status.articleID] = status
		}
	}

	func addStatusIfNotCached(_ status: ArticleStatus) {
		addIfNotCached(Set([status]))
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

	subscript(_ articleID: String) -> ArticleStatus? {
		get {
			return dictionary[articleID]
		}
		set {
			dictionary[articleID] = newValue
		}
	}
}


