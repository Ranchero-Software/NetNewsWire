//
//  SyncStatusTable.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import RSDatabase
import RSDatabaseObjC

struct SyncStatusTable {
	static let name = "syncStatus"

	static func selectForProcessing(limit: Int?, database: FMDatabase) -> Set<SyncStatus>? {
		database.beginTransaction()
		defer {
			database.commit()
		}

		let updateSQL = "update \(name) set selected = true"
		database.executeUpdate(updateSQL, withArgumentsIn: nil)

		let selectSQL = {
			var sql = "select * from \(name) where selected == true"
			if let limit {
				sql = "\(sql) limit \(limit)"
			}
			return sql
		}()

		guard let resultSet = database.executeQuery(selectSQL, withArgumentsIn: nil) else {
			return nil
		}
		let statuses = resultSet.mapToSet(statusWithRow)
		return statuses
	}

	static func selectPendingCount(database: FMDatabase) -> Int? {
		let sql = "select count(*) from \(name)"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let count = resultSet.intWithCountResult()
		return count
	}

	static func selectPendingReadStatusArticleIDs(database: FMDatabase) -> Set<String>? {
		selectPendingArticleIDs(.read, database: database)
	}

	static func selectPendingStarredStatusArticleIDs(database: FMDatabase) -> Set<String>? {
		selectPendingArticleIDs(.starred, database: database)
	}

	static func resetAllSelectedForProcessing(database: FMDatabase) {
		let updateSQL = "update \(name) set selected = false"
		database.executeUpdateInTransaction(updateSQL)
	}

	static func resetSelectedForProcessing(_ articleIDs: Set<String>, database: FMDatabase) {
		guard !articleIDs.isEmpty else {
			return
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let updateSQL = "update \(name) set selected = false where articleID in \(placeholders)"
		database.executeUpdateInTransaction(updateSQL, withArgumentsIn: parameters)
	}

	static func deleteSelectedForProcessing(_ articleIDs: Set<String>, database: FMDatabase) {
		guard !articleIDs.isEmpty else {
			return
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let deleteSQL = "delete from \(name) where selected = true and articleID in \(placeholders)"
		database.executeUpdateInTransaction(deleteSQL, withArgumentsIn: parameters)
	}

	static func insertStatuses(_ statuses: Set<SyncStatus>, database: FMDatabase) {
		database.beginTransaction()
		defer {
			database.commit()
		}

		let statusArray = statuses.map { $0.databaseDictionary() }
		database.insertRows(statusArray, insertType: .orReplace, tableName: name)
	}
}

private extension SyncStatusTable {

	static func statusWithRow(_ row: FMResultSet) -> SyncStatus? {
		guard let articleID = row.string(forColumn: DatabaseKey.articleID),
			let rawKey = row.string(forColumn: DatabaseKey.key),
			let key = SyncStatus.Key(rawValue: rawKey) else {
				return nil
		}

		let flag = row.bool(forColumn: DatabaseKey.flag)
		let selected = row.bool(forColumn: DatabaseKey.selected)

		return SyncStatus(articleID: articleID, key: key, flag: flag, selected: selected)
	}

	static func selectPendingArticleIDs(_ statusKey: ArticleStatus.Key, database: FMDatabase) -> Set<String>? {
		let sql = "select articleID from \(name) where selected == false and key = \"\(statusKey.rawValue)\";"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
		return articleIDs
	}
}
