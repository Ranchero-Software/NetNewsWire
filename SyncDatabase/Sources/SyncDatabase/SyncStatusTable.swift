//
//  SyncStatusTable.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Articles
import Database
import FMDB

actor SyncStatusTable {

	static private let tableName = "syncStatus"

	private var database: FMDatabase?
	private let databasePath: String

	init(databasePath: String) {

		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.runCreateStatements(SyncStatusTable.creationStatements)
		database.vacuum()

		self.database = database
		self.databasePath = databasePath
	}

	func suspend() {
#if os(iOS)
		database?.close()
		database = nil
#endif
	}

	func resume() {
#if os(iOS)
		if database == nil {
			self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		}
#endif
	}

	func close() {
		
		database?.close()
	}

	func selectForProcessing(limit: Int?) throws -> Set<SyncStatus>? {

		guard let database else {
			throw DatabaseError.suspended
		}

		let updateSQL = "update syncStatus set selected = true"
		database.executeUpdateInTransaction(updateSQL, withArgumentsIn: nil)

		let selectSQL = {
			var sql = "select * from syncStatus where selected == true"
			if let limit {
				sql = "\(sql) limit \(limit)"
			}
			return sql
		}()

		guard let resultSet = database.executeQuery(selectSQL, withArgumentsIn: nil) else {
			return nil
		}
		let statuses = resultSet.mapToSet(self.statusWithRow)
		return statuses
	}

	func selectPendingCount() throws -> Int? {

		guard let database else {
			throw DatabaseError.suspended
		}

		let sql = "select count(*) from syncStatus"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let count = resultSet.intWithCountResult()
		return count
	}

	func selectPendingReadStatusArticleIDs() throws -> Set<String>? {
		try selectPendingArticleIDs(.read)
	}

	func selectPendingStarredStatusArticleIDs() throws -> Set<String>? {
		try selectPendingArticleIDs(.starred)
	}

	func resetAllSelectedForProcessing() throws {

		guard let database else {
			throw DatabaseError.suspended
		}

		let updateSQL = "update syncStatus set selected = false"
		database.executeUpdateInTransaction(updateSQL, withArgumentsIn: nil)
	}

	func resetSelectedForProcessing(_ articleIDs: [String]) throws {

		guard !articleIDs.isEmpty else {
			return
		}
		guard let database else {
			throw DatabaseError.suspended
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let updateSQL = "update syncStatus set selected = false where articleID in \(placeholders)"

		database.executeUpdateInTransaction(updateSQL, withArgumentsIn: parameters)
	}

	func deleteSelectedForProcessing(_ articleIDs: [String]) throws {

		guard !articleIDs.isEmpty else {
			return
		}
		guard let database else {
			throw DatabaseError.suspended
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let deleteSQL = "delete from syncStatus where selected = true and articleID in \(placeholders)"

		database.executeUpdateInTransaction(deleteSQL, withArgumentsIn: parameters)
	}

	func insertStatuses(_ statuses: [SyncStatus]) throws {

		guard let database else {
			throw DatabaseError.suspended
		}

		database.beginTransaction()

		let statusArray = statuses.map { $0.databaseDictionary() }
		database.insertRows(statusArray, insertType: .orReplace, tableName: Self.tableName)

		database.commit()
	}
}

private extension SyncStatusTable {

	static let creationStatements = """
	CREATE TABLE if not EXISTS syncStatus (articleID TEXT NOT NULL, key TEXT NOT NULL, flag BOOL NOT NULL DEFAULT 0, selected BOOL NOT NULL DEFAULT 0, PRIMARY KEY (articleID, key));
	"""

	func statusWithRow(_ row: FMResultSet) -> SyncStatus? {

		guard let articleID = row.string(forColumn: DatabaseKey.articleID),
			let rawKey = row.string(forColumn: DatabaseKey.key),
			let key = SyncStatus.Key(rawValue: rawKey) else {
				return nil
		}
		
		let flag = row.bool(forColumn: DatabaseKey.flag)
		let selected = row.bool(forColumn: DatabaseKey.selected)
		
		return SyncStatus(articleID: articleID, key: key, flag: flag, selected: selected)
	}

	func selectPendingArticleIDs(_ statusKey: ArticleStatus.Key) throws -> Set<String>? {

		guard let database else {
			throw DatabaseError.suspended
		}

		let sql = "select articleID from syncStatus where selected == false and key = \"\(statusKey.rawValue)\";"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
		return articleIDs
	}
}
