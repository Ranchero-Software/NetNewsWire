//
//  FetchAllUnreadCountsOperation.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 1/26/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase

public final class FetchAllUnreadCountsOperation: MainThreadOperation {

	var result: UnreadCountDictionaryCompletionResult = .failure(.isSuspended)

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "FetchAllUnreadCountsOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private let queue: DatabaseQueue
	private let cutoffDate: Date

	init(databaseQueue: DatabaseQueue, cutoffDate: Date) {
		self.queue = databaseQueue
		self.cutoffDate = cutoffDate
	}
	
	public func run() {
		queue.runInDatabase { databaseResult in
			if self.isCanceled {
				self.informOperationDelegateOfCompletion()
				return
			}

			switch databaseResult {
			case .success(let database):
				self.fetchUnreadCounts(database)
			case .failure:
				self.informOperationDelegateOfCompletion()
			}
		}
	}
}

private extension FetchAllUnreadCountsOperation {

	func fetchUnreadCounts(_ database: FMDatabase) {
		let sql = "select distinct feedID, count(*) from articles natural join statuses where read=0 and userDeleted=0 and (starred=1 or dateArrived>?) group by feedID;"

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate]) else {
			informOperationDelegateOfCompletion()
			return
		}

		var unreadCountDictionary = UnreadCountDictionary()
		while resultSet.next() {
			if isCanceled {
				resultSet.close()
				informOperationDelegateOfCompletion()
				return
			}
			let unreadCount = resultSet.long(forColumnIndex: 1)
			if let webFeedID = resultSet.string(forColumnIndex: 0) {
				unreadCountDictionary[webFeedID] = unreadCount
			}
		}
		resultSet.close()

		result = .success(unreadCountDictionary)
		informOperationDelegateOfCompletion()
	}
}
