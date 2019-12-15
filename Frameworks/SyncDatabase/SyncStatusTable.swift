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
import RSDatabase

struct SyncStatusTable: DatabaseTable {

	let name = DatabaseTableName.syncStatus
	private let queue: DatabaseQueue

	init(queue: DatabaseQueue) {
		self.queue = queue
	}

	func selectForProcessing() -> [SyncStatus] {
		var statuses: Set<SyncStatus>? = nil
		
		guard !queue.isSuspended else {
			return [SyncStatus]()
		}
		
		queue.runInDatabaseSync { database in
			let updateSQL = "update syncStatus set selected = true"
			database.executeUpdate(updateSQL, withArgumentsIn: nil)
			
			let selectSQL = "select * from syncStatus where selected == true"
			if let resultSet = database.executeQuery(selectSQL, withArgumentsIn: nil) {
				statuses = resultSet.mapToSet(self.statusWithRow)
			}
		}

		return statuses != nil ? Array(statuses!) : [SyncStatus]()
	}
	
	func selectPendingCount() -> Int {
		var count: Int = 0
		
		guard !queue.isSuspended else {
			return count
		}
		
		queue.runInDatabaseSync { database in
			let sql = "select count(*) from syncStatus"
			if let resultSet = database.executeQuery(sql, withArgumentsIn: nil) {
				count = numberWithCountResultSet(resultSet)
			}
		}
		
		return count
	}
	
	func resetSelectedForProcessing(_ articleIDs: [String], completion: VoidCompletionBlock? = nil) {
		guard !queue.isSuspended else {
            if let completion = completion {
				callVoidCompletionBlock(completion)
            }
			return
		}
		queue.runInTransaction { database in
			let parameters = articleIDs.map { $0 as AnyObject }
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
			let updateSQL = "update syncStatus set selected = false where articleID in \(placeholders)"
			database.executeUpdate(updateSQL, withArgumentsIn: parameters)
            if let completion = completion {
				callVoidCompletionBlock(completion)
            }
		}
	}
	
    func deleteSelectedForProcessing(_ articleIDs: [String], completion: VoidCompletionBlock? = nil) {
		guard !queue.isSuspended else {
            if let completion = completion {
				callVoidCompletionBlock(completion)
            }
			return
		}
		queue.runInTransaction { database in
			let parameters = articleIDs.map { $0 as AnyObject }
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
			let deleteSQL = "delete from syncStatus where articleID in \(placeholders)"
			database.executeUpdate(deleteSQL, withArgumentsIn: parameters)
            if let completion = completion {
 				callVoidCompletionBlock(completion)
            }
		}
	}
	
	func insertStatuses(_ statuses: [SyncStatus], completion: VoidCompletionBlock? = nil) {
		guard !queue.isSuspended else {
            if let completion = completion {
				callVoidCompletionBlock(completion)
            }
			return
		}
		queue.runInTransaction { database in
			let statusArray = statuses.map { $0.databaseDictionary() }
			self.insertRows(statusArray, insertType: .orReplace, in: database)
            if let completion = completion {
				callVoidCompletionBlock(completion)
            }
		}
	}
}

private extension SyncStatusTable {

	func statusWithRow(_ row: FMResultSet) -> SyncStatus? {
		guard let articleID = row.string(forColumn: DatabaseKey.articleID),
			let rawKey = row.string(forColumn: DatabaseKey.key),
			let key = ArticleStatus.Key(rawValue: rawKey) else {
				return nil
		}
		
		let flag = row.bool(forColumn: DatabaseKey.flag)
		let selected = row.bool(forColumn: DatabaseKey.selected)
		
		return SyncStatus(articleID: articleID, key: key, flag: flag, selected: selected)
	}
}
