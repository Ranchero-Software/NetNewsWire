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
import RSDatabaseObjC
import Articles

// Article->ArticleStatus is a to-one relationship.
//
// CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

final class StatusesTable: DatabaseTable {

	let name = DatabaseTableName.statuses
	private let cache = StatusCache()
	private let queue: DatabaseQueue
	
	init(queue: DatabaseQueue) {
		self.queue = queue
	}

	// MARK: - Creating/Updating

	func ensureStatusesForArticleIDs(_ articleIDs: Set<String>, _ read: Bool, _ database: FMDatabase) -> ([String: ArticleStatus], Set<String>) {

		#if DEBUG
		// Check for missing statuses  — this asserts that all the passed-in articleIDs exist in the statuses table.
		defer {
			if let resultSet = self.selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) {
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

	func markAndFetchNew(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) -> Set<String> {
		let (statusesDictionary, newStatusIDs) = ensureStatusesForArticleIDs(articleIDs, flag, database)
		let statuses = Set(statusesDictionary.values)
		mark(statuses, statusKey, flag, database)
		return newStatusIDs
	}

	// MARK: - Fetching

	func fetchUnreadArticleIDs() throws -> Set<String> {
		return try fetchArticleIDs("select articleID from statuses where read=0;")
	}

	func fetchStarredArticleIDs() throws -> Set<String> {
		return try fetchArticleIDs("select articleID from statuses where starred=1;")
	}
	
	func fetchArticleIDsAsync(_ statusKey: ArticleStatus.Key, _ value: Bool, _ completion: @escaping ArticleIDsCompletionBlock) {
		queue.runInDatabase { databaseResult in

			func makeDatabaseCalls(_ database: FMDatabase) {
				var sql = "select articleID from statuses where \(statusKey.rawValue)="
				sql += value ? "1" : "0"
				sql += ";"

				guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
					DispatchQueue.main.async {
						completion(.success(Set<String>()))
					}
					return
				}

				let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
				DispatchQueue.main.async {
					completion(.success(articleIDs))
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func fetchArticleIDsForStatusesWithoutArticlesNewerThan(_ cutoffDate: Date, _ completion: @escaping ArticleIDsCompletionBlock) {
		queue.runInDatabase { databaseResult in
			
			var error: DatabaseError?
			var articleIDs = Set<String>()
			
			func makeDatabaseCall(_ database: FMDatabase) {
				let sql = "select articleID from statuses s where (starred=1 or dateArrived>?) and not exists (select 1 from articles a where a.articleID = s.articleID);"
				if let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate]) {
					articleIDs = resultSet.mapToSet(self.articleIDWithRow)
				}
			}
			
			switch databaseResult {
			case .success(let database):
				makeDatabaseCall(database)
			case .failure(let databaseError):
				error = databaseError
			}
			
			if let error = error {
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
			else {
				DispatchQueue.main.async {
					completion(.success(articleIDs))
				}
			}
		}
	}
	
	func fetchArticleIDs(_ sql: String) throws -> Set<String> {
		var error: DatabaseError?
		var articleIDs = Set<String>()
		queue.runInDatabaseSync { databaseResult in
			switch databaseResult {
			case .success(let database):
				if let resultSet = database.executeQuery(sql, withArgumentsIn: nil) {
					articleIDs = resultSet.mapToSet(self.articleIDWithRow)
				}
			case .failure(let databaseError):
				error = databaseError
			}
		}

		if let error = error {
			throw(error)
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


