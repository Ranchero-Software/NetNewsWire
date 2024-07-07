//
//  SyncStatusTable.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Database
import FMDB

struct SyncStatusTable {

	static private let name = "syncStatus"

	func selectForProcessing(limit: Int?, database: FMDatabase) -> Set<SyncStatus>? {

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

	func selectPendingCount(database: FMDatabase) -> Int? {

		let sql = "select count(*) from syncStatus"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let count = resultSet.intWithCountResult()
		return count
	}

	func selectPendingReadStatusArticleIDs(database: FMDatabase) -> Set<String>? {

		selectPendingArticleIDs(.read, database: database)
	}

	func selectPendingStarredStatusArticleIDs(database: FMDatabase) -> Set<String>? {

		selectPendingArticleIDs(.starred, database: database)
	}

	func resetAllSelectedForProcessing(database: FMDatabase) {

		let updateSQL = "update syncStatus set selected = false"
		database.executeUpdateInTransaction(updateSQL)
	}

	func resetSelectedForProcessing(_ articleIDs: Set<String>, database: FMDatabase) {

		guard !articleIDs.isEmpty else {
			return
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let updateSQL = "update syncStatus set selected = false where articleID in \(placeholders)"

		database.executeUpdateInTransaction(updateSQL, withArgumentsIn: parameters)
	}

	func deleteSelectedForProcessing(_ articleIDs: Set<String>, database: FMDatabase) {

		guard !articleIDs.isEmpty else {
			return
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let deleteSQL = "delete from syncStatus where selected = true and articleID in \(placeholders)"

		database.executeUpdateInTransaction(deleteSQL, withArgumentsIn: parameters)
	}

	func insertStatuses(_ statuses: Set<SyncStatus>, database: FMDatabase) {

		database.beginTransaction()

		let statusArray = statuses.map { $0.databaseDictionary() }
		database.insertRows(statusArray, insertType: .orReplace, tableName: Self.name)

		database.commit()
	}
}

private extension SyncStatusTable {

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

	func selectPendingArticleIDs(_ statusKey: ArticleStatus.Key, database: FMDatabase) -> Set<String>? {

		let sql = "select articleID from syncStatus where selected == false and key = \"\(statusKey.rawValue)\";"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
		return articleIDs
	}
}
