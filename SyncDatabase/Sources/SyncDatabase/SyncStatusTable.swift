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
import RSDatabaseObjC

struct SyncStatusTable: DatabaseTable {

	let name = DatabaseTableName.syncStatus
	private let queue: DatabaseQueue

	init(queue: DatabaseQueue) {
		self.queue = queue
	}

	func selectForProcessing(limit: Int?) async throws -> Set<SyncStatus> {

		return try await withCheckedThrowingContinuation { continuation in
			queue.runInTransaction { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) -> Set<SyncStatus> {
					let updateSQL = "update syncStatus set selected = true"
					database.executeUpdate(updateSQL, withArgumentsIn: nil)

					var selectSQL = "select * from syncStatus where selected == true"
					if let limit = limit {
						selectSQL = "\(selectSQL) limit \(limit)"
					}

					var statuses = Set<SyncStatus>()
					if let resultSet = database.executeQuery(selectSQL, withArgumentsIn: nil) {
						statuses = resultSet.mapToSet(self.statusWithRow)
					}
					return statuses
				}

				switch databaseResult {
				case .success(let database):
					let statuses = makeDatabaseCall(database)
					continuation.resume(returning: statuses)
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
	}

	func selectPendingCount() async throws -> Int {

		try await withCheckedThrowingContinuation { continuation in
			queue.runInDatabase { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) -> Int {
					let sql = "select count(*) from syncStatus"
					var count = 0
					if let resultSet = database.executeQuery(sql, withArgumentsIn: nil) {
						count = self.numberWithCountResultSet(resultSet)
					}
					return count
				}

				switch databaseResult {
				case .success(let database):
					let count = makeDatabaseCall(database)
					continuation.resume(returning: count)
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
	}

    func selectPendingReadArticleIDs() async throws -> Set<String> {
        return try await selectPendingArticleIDs(.read)
    }

    func selectPendingStarredArticleIDs() async throws -> Set<String> {
        return try await selectPendingArticleIDs(.starred)
    }

	func resetAllSelectedForProcessing() async throws {

		try await withCheckedThrowingContinuation { continuation in
			queue.runInTransaction { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) {
					let updateSQL = "update syncStatus set selected = false"
					database.executeUpdate(updateSQL, withArgumentsIn: nil)
				}

				switch databaseResult {
				case .success(let database):
					makeDatabaseCall(database)
					continuation.resume()
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
	}

	func resetSelectedForProcessing(_ articleIDs: [String]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			guard !articleIDs.isEmpty else {
				continuation.resume()
				return
			}

			queue.runInTransaction { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) {
					let parameters = articleIDs.map { $0 as AnyObject }
					let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
					let updateSQL = "update syncStatus set selected = false where articleID in \(placeholders)"
					database.executeUpdate(updateSQL, withArgumentsIn: parameters)
				}

				switch databaseResult {
				case .success(let database):
					makeDatabaseCall(database)
					continuation.resume()
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
	}

	func deleteSelectedForProcessing(_ articleIDs: [String]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			guard !articleIDs.isEmpty else {
				continuation.resume()
				return
			}

			queue.runInTransaction { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) {
					let parameters = articleIDs.map { $0 as AnyObject }
					let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
					let deleteSQL = "delete from syncStatus where selected = true and articleID in \(placeholders)"
					database.executeUpdate(deleteSQL, withArgumentsIn: parameters)
				}

				switch databaseResult {
				case .success(let database):
					makeDatabaseCall(database)
					continuation.resume()
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
	}

	func insertStatuses(_ statuses: [SyncStatus]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			queue.runInTransaction { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) {
					let statusArray = statuses.map { $0.databaseDictionary() }
					self.insertRows(statusArray, insertType: .orReplace, in: database)
				}

				switch databaseResult {
				case .success(let database):
					makeDatabaseCall(database)
					continuation.resume()
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
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

	func selectPendingArticleIDs(_ statusKey: ArticleStatus.Key) async throws -> Set<String> {

		return try await withCheckedThrowingContinuation { continuation in
			queue.runInDatabase { databaseResult in

				func makeDatabaseCall(_ database: FMDatabase) -> Set<String> {
					let sql = "select articleID from syncStatus where selected == false and key = \"\(statusKey.rawValue)\";"

					guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
						return Set<String>()
					}

					let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
					return articleIDs
				}

				switch databaseResult {
				case .success(let database):
					let articleIDs = makeDatabaseCall(database)
					continuation.resume(returning: articleIDs)
				case .failure(let databaseError):
					continuation.resume(throwing: databaseError)
				}
			}
		}
	}
}
