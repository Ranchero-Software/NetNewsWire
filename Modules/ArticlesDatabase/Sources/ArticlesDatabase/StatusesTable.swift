//
//  StatusesTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Database
import Articles
import FMDB

// Article->ArticleStatus is a to-one relationship.
//
// CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

final class StatusesTable {

	let name = DatabaseTableName.statuses
	private let cache = StatusCache()

	// MARK: - Creating/Updating

	@discardableResult
	func ensureStatusesForArticleIDs(_ articleIDs: Set<String>, _ read: Bool, _ database: FMDatabase) -> ([String: ArticleStatus], Set<String>) {

		#if DEBUG
		// Check for missing statuses  — this asserts that all the passed-in articleIDs exist in the statuses table.
		defer {
			if let resultSet = database.selectRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), tableName: name) {
				let fetchedStatuses = resultSet.mapToSet(statusWithRow)
				let fetchedArticleIDs = Set(fetchedStatuses.map{ $0.articleID })
				assert(fetchedArticleIDs == articleIDs)
			}
		}
		#endif

		// Check cache.
		let articleIDsMissingCachedStatus = articleIDsWithNoCachedStatus(articleIDs)
		if articleIDsMissingCachedStatus.isEmpty {
			return (statusesDictionary(articleIDs), Set<String>())
		}
		
		// Check database.
		fetchAndCacheStatusesForArticleIDs(articleIDsMissingCachedStatus, database)
			
		let articleIDsNeedingStatus = self.articleIDsWithNoCachedStatus(articleIDs)
		if !articleIDsNeedingStatus.isEmpty {
			// Create new statuses.
			self.createAndSaveStatusesForArticleIDs(articleIDsNeedingStatus, read, database)
		}

		return (statusesDictionary(articleIDs), articleIDsNeedingStatus)
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

	func mark(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) {
		let (statusesDictionary, _) = ensureStatusesForArticleIDs(articleIDs, flag, database)
		let statuses = Set(statusesDictionary.values)
		mark(statuses, statusKey, flag, database)
	}

	// MARK: - Fetching

	func articleIDs(key: ArticleStatus.Key, value: Bool, database: FMDatabase) -> Set<String>? {

		var sql = "select articleID from statuses where \(key.rawValue)="
		sql += value ? "1" : "0"
		sql += ";"

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
		return articleIDs
	}


	func articleIDsForStatusesWithoutArticlesNewerThan(cutoffDate: Date, database: FMDatabase) -> Set<String>? {

		let sql = "select articleID from statuses s where (starred=1 or dateArrived>?) and not exists (select 1 from articles a where a.articleID = s.articleID);"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate]) else {
			return nil
		}

		let articleIDs = resultSet.mapToSet(articleIDWithRow)
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
		
		database.deleteRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), tableName: name)
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
		database.insertRows(statusArray, insertType: .orIgnore, tableName: name)
	}

	func createAndSaveStatusesForArticleIDs(_ articleIDs: Set<String>, _ read: Bool, _ database: FMDatabase) {
		let now = Date()
		let statuses = Set(articleIDs.map { ArticleStatus(articleID: $0, read: read, dateArrived: now) })
		cache.addIfNotCached(statuses)
		
		saveStatuses(statuses, database)
	}

	func fetchAndCacheStatusesForArticleIDs(_ articleIDs: Set<String>, _ database: FMDatabase) {
		guard let resultSet = database.selectRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), tableName: name) else {
			return
		}
		
		let statuses = resultSet.mapToSet(self.statusWithRow)
		self.cache.addIfNotCached(statuses)
	}

	// MARK: - Marking

	func markArticleIDs(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) {

		database.updateRowsWithValue(NSNumber(value: flag), valueKey: statusKey.rawValue, whereKey: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), tableName: name)
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


