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

	func selectForProcessing(limit: Int?, completion: @escaping SyncStatusesCompletionBlock) {
		queue.runInTransaction { databaseResult in
			var statuses = Set<SyncStatus>()
			var error: DatabaseError?

			func makeDatabaseCall(_ database: FMDatabase) {
				let updateSQL = "update syncStatus set selected = true"
				database.executeUpdate(updateSQL, withArgumentsIn: nil)

				var selectSQL = "select * from syncStatus where selected == true"
				if let limit = limit {
					selectSQL = "\(selectSQL) limit \(limit)"
				}
				if let resultSet = database.executeQuery(selectSQL, withArgumentsIn: nil) {
					statuses = resultSet.mapToSet(self.statusWithRow)
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCall(database)
			case .failure(let databaseError):
				error = databaseError
			}

			DispatchQueue.main.async {
				if let error = error {
					completion(.failure(error))
				}
				else {
					completion(.success(Array(statuses)))
				}
			}
		}
	}
	
	func selectPendingCount(_ completion: @escaping DatabaseIntCompletionBlock) {
		queue.runInDatabase { databaseResult in
			var count: Int = 0
			var error: DatabaseError?

			func makeDatabaseCall(_ database: FMDatabase) {
				let sql = "select count(*) from syncStatus"
				if let resultSet = database.executeQuery(sql, withArgumentsIn: nil) {
					count = self.numberWithCountResultSet(resultSet)
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCall(database)
			case .failure(let databaseError):
				error = databaseError
			}

			DispatchQueue.main.async {
				if let error = error {
					completion(.failure(error))
				}
				else {
					completion(.success(count))
				}
			}
		}
	}

    func selectPendingReadStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {
        selectPendingArticleIDsAsync(.read, completion)
    }
    
    func selectPendingStarredStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {
        selectPendingArticleIDsAsync(.starred, completion)
    }
    
	func resetAllSelectedForProcessing(completion: DatabaseCompletionBlock? = nil) {
		queue.runInTransaction { databaseResult in

			func makeDatabaseCall(_ database: FMDatabase) {
				let updateSQL = "update syncStatus set selected = false"
				database.executeUpdate(updateSQL, withArgumentsIn: nil)
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCall(database)
				callCompletion(completion, nil)
			case .failure(let databaseError):
				callCompletion(completion, databaseError)
			}
		}
	}

	func resetSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {
		guard !articleIDs.isEmpty else {
			callCompletion(completion, nil)
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
				callCompletion(completion, nil)
			case .failure(let databaseError):
				callCompletion(completion, databaseError)
			}
		}
	}
	
    func deleteSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {
		guard !articleIDs.isEmpty else {
			callCompletion(completion, nil)
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
				callCompletion(completion, nil)
			case .failure(let databaseError):
				callCompletion(completion, databaseError)
			}
		}
	}
	
    func insertStatuses(_ statuses: [SyncStatus], completion: @escaping DatabaseCompletionBlock) {
		queue.runInTransaction { databaseResult in

			func makeDatabaseCall(_ database: FMDatabase) {
				let statusArray = statuses.map { $0.databaseDictionary() }
				self.insertRows(statusArray, insertType: .orReplace, in: database)
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCall(database)
				callCompletion(completion, nil)
			case .failure(let databaseError):
				callCompletion(completion, databaseError)
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
    
    func selectPendingArticleIDsAsync(_ statusKey: ArticleStatus.Key, _ completion: @escaping SyncStatusArticleIDsCompletionBlock) {

        queue.runInDatabase { databaseResult in

            func makeDatabaseCall(_ database: FMDatabase) {
                let sql = "select articleID from syncStatus where selected == false and key = \"\(statusKey.rawValue)\";"

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
                makeDatabaseCall(database)
            case .failure(let databaseError):
                DispatchQueue.main.async {
                    completion(.failure(databaseError))
                }
            }
        }
    }
    
}

private func callCompletion(_ completion: DatabaseCompletionBlock?, _ databaseError: DatabaseError?) {
	guard let completion = completion else {
		return
	}
	DispatchQueue.main.async {
		completion(databaseError)
	}
}
