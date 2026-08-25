//
//  StatusesTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSCore
import RSDatabase
import RSDatabaseObjC
import Articles

// Article->ArticleStatus is a to-one relationship.
//
// CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

final class StatusesTable: DatabaseTable, Sendable {
	let name = DatabaseTableName.statuses
	private let cache = StatusCache()
	private let queue: DatabaseQueue

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "StatusesTable")

	init(queue: DatabaseQueue) {
		self.queue = queue
	}

	// MARK: - Creating/Updating

	@discardableResult
	func ensureStatusesForArticleIDs(_ articleIDs: Set<String>, _ read: Bool, _ database: FMDatabase) -> ([String: ArticleStatus], Set<String>) {

		#if DEBUG
		// Check for missing statuses  — this asserts that all the passed-in articleIDs exist in the statuses table.
		defer {
			if let resultSet = self.selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) {
				let fetchedStatuses = resultSet.mapToSet(statusWithRow)
				let fetchedArticleIDs = Set(fetchedStatuses.map { $0.articleID })
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

		if statuses.isEmpty {
			return nil
		}

		// Update all requested articleIDs, not just the ones that changed in memory, just to be sure.
		// (Doesn’t actually write to the database where it already matches.)
		markArticleIDs(statuses.articleIDs(), statusKey, flag, database)

		return updatedStatuses.isEmpty ? nil : updatedStatuses
	}

	func markAndFetchNew(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) -> Set<String> {
		let (statusesDictionary, newStatusIDs) = ensureStatusesForArticleIDs(articleIDs, flag, database)
		let statuses = Set(statusesDictionary.values)
		mark(statuses, statusKey, flag, database)
		return newStatusIDs
	}

	/// Mark statuses for articleIDs in both memory and database. Returns the articleIDs whose status actually changed.
	func mark(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ database: FMDatabase) -> Set<String> {
		let (statusesDictionary, _) = ensureStatusesForArticleIDs(articleIDs, flag, database)
		let updatedStatuses = mark(Set(statusesDictionary.values), statusKey, flag, database)
		return updatedStatuses?.articleIDs() ?? Set<String>()
	}

	// MARK: - Repairing

	/// Repair status rows that disagree with their in-memory statuses — the
	/// in-memory status is the newer side when a database write was lost.
	/// Only cached statuses can disagree, so they're the ones to check.
	func repairStatuses(_ database: FMDatabase) {
		let cachedStatuses = Array(cache.allStatuses)
		guard !cachedStatuses.isEmpty else {
			return
		}

		// Stay well under SQLite's bind-variable limit.
		let chunkSize = 500

		var statusesNeedingRepair = Set<ArticleStatus>()
		for chunkStartIndex in stride(from: 0, to: cachedStatuses.count, by: chunkSize) {
			let chunk = Array(cachedStatuses[chunkStartIndex..<min(chunkStartIndex + chunkSize, cachedStatuses.count)])
			statusesNeedingRepair.formUnion(staleStatuses(in: chunk, database))
		}

		if !statusesNeedingRepair.isEmpty {
			Self.logger.info("StatusesTable: repairing \(statusesNeedingRepair.count, privacy: .public) stale statuses")
			saveStatusFlags(statusesNeedingRepair, database)
		}
	}

	// MARK: - Fetching

	func fetchUnreadArticleIDs() -> Set<String> {
		fetchArticleIDs("select articleID from statuses where read=0;")
	}

	func fetchStarredArticleIDs() -> Set<String> {
		fetchArticleIDs("select articleID from statuses where starred=1;")
	}

	func fetchArticleIDsAsync(_ statusKey: ArticleStatus.Key, _ value: Bool, _ completion: @escaping ArticleIDsCompletionBlock) {
		queue.runInDatabase { database in
			var sql = "select articleID from statuses where \(statusKey.rawValue)="
			sql += value ? "1" : "0"
			sql += ";"

			guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
				DispatchQueue.main.async {
					completion(Set<String>())
				}
				return
			}

			let articleIDs = resultSet.mapToSet { $0.swiftString(forColumnIndex: 0) }
			DispatchQueue.main.async {
				completion(articleIDs)
			}
		}
	}

	func fetchArticleIDsForStatusesWithoutArticlesNewerThan(_ cutoffDate: Date, _ completion: @escaping ArticleIDsCompletionBlock) {
		queue.runInDatabase { database in
			let sql = "select articleID from statuses s where (starred=1 or dateArrived>?) and not exists (select 1 from articles a where a.articleID = s.articleID);"
			let articleIDs: Set<String>
			if let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate]) {
				articleIDs = resultSet.mapToSet(self.articleIDWithRow)
			} else {
				articleIDs = Set<String>()
			}

			DispatchQueue.main.async {
				completion(articleIDs)
			}
		}
	}

	func fetchArticleIDs(_ sql: String) -> Set<String> {
		nonisolated(unsafe) var articleIDs = Set<String>()
		queue.runInDatabaseSync { database in
			if let resultSet = database.executeQuery(sql, withArgumentsIn: nil) {
				articleIDs = resultSet.mapToSet(self.articleIDWithRow)
			}
		}

		return articleIDs
	}

	func articleIDWithRow(_ row: FMResultSet) -> String? {
		return row.swiftString(forColumn: DatabaseKey.articleID)
	}

	func statusWithRow(_ row: FMResultSet) -> ArticleStatus? {
		guard let articleID = row.swiftString(forColumn: DatabaseKey.articleID) else {
			return nil
		}
		return statusWithRow(row, articleID: articleID)
	}

	func statusWithRow(_ row: FMResultSet, articleID: String) -> ArticleStatus? {
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

	// MARK: - Repairing

	/// The statuses whose database rows disagree with them.
	func staleStatuses(in statuses: [ArticleStatus], _ database: FMDatabase) -> Set<ArticleStatus> {
		guard let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(statuses.count)) else {
			return Set<ArticleStatus>()
		}
		let statusesByArticleID = Dictionary(statuses.map { ($0.articleID, $0) }, uniquingKeysWith: { first, _ in first })
		let sql = "select articleID, read, starred from statuses where articleID in \(placeholders);"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: statuses.map { $0.articleID }) else {
			return Set<ArticleStatus>()
		}

		let articleIDColumnIndex: Int32 = 0
		let readColumnIndex: Int32 = 1
		let starredColumnIndex: Int32 = 2

		var staleStatuses = Set<ArticleStatus>()
		while resultSet.next() {
			guard let articleID = resultSet.swiftString(forColumnIndex: articleIDColumnIndex), let status = statusesByArticleID[articleID] else {
				continue
			}
			if status.read != resultSet.bool(forColumnIndex: readColumnIndex) || status.starred != resultSet.bool(forColumnIndex: starredColumnIndex) {
				staleStatuses.insert(status)
			}
		}
		resultSet.close()

		return staleStatuses
	}

	/// Rewrite status rows from their in-memory statuses.
	func saveStatusFlags(_ statuses: Set<ArticleStatus>, _ database: FMDatabase) {
		for status in statuses {
			database.executeUpdate("update statuses set read=?, starred=? where articleID=?;", withArgumentsIn: [status.read, status.starred, status.articleID])
		}
	}

	// MARK: - Cache

	func articleIDsWithNoCachedStatus(_ articleIDs: Set<String>) -> Set<String> {
		return Set(articleIDs.filter { cache[$0] == nil })
	}

	// MARK: - Creating

	func saveStatuses(_ statuses: Set<ArticleStatus>, _ database: FMDatabase) {
		let statusArray = statuses.map { $0.databaseDictionary() }
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
		guard !articleIDs.isEmpty else {
			return
		}
		guard let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count)) else {
			return
		}
		let sql = "update statuses set \(statusKey.rawValue)=? where articleID in \(placeholders) and \(statusKey.rawValue)!=?;"
		let parameters: [Any] = [flag] + Array(articleIDs) + [flag]
		database.executeUpdate(sql, withArgumentsIn: parameters)
	}

}

// MARK: - StatusCache

private final class StatusCache: Sendable {
	private struct State {
		var dictionary = [String: ArticleStatus]()
	}

	private let state = OSAllocatedUnfairLock(initialState: State())

	func addStatusIfNotCached(_ status: ArticleStatus) {
		addIfNotCached(Set([status]))
	}

	func addIfNotCached(_ statuses: Set<ArticleStatus>) {
		// Does not replace already cached statuses.
		state.withLock { state in
			for status in statuses {
				let articleID = status.articleID
				if state.dictionary[articleID] == nil {
					state.dictionary[articleID] = status
				}
			}
		}
	}

	var allStatuses: Set<ArticleStatus> {
		state.withLock { Set($0.dictionary.values) }
	}

	subscript(_ articleID: String) -> ArticleStatus? {
		get {
			state.withLock { $0.dictionary[articleID] }
		}
		set {
			state.withLock { $0.dictionary[articleID] = newValue }
		}
	}
}
