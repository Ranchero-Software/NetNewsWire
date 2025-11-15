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
import RSDatabaseObjC

public final class FetchAllUnreadCountsOperation: MainThreadOperation, @unchecked Sendable {
	var result: UnreadCountDictionaryCompletionResult?
	private let queue: DatabaseQueue

	init(databaseQueue: DatabaseQueue) {
		self.queue = databaseQueue
		super.init(name: "FetchAllUnreadCountsOperation")
	}

	@MainActor public override func run() {
		queue.runInDatabase { databaseResult in
			if self.isCanceled {
				self.didComplete()
				return
			}
			
			switch databaseResult {
			case .success(let database):
				self.result = self.fetchUnreadCounts(database)
			case .failure:
				self.result = .failure(.isSuspended)
			}

			self.didComplete()
		}
	}
}

nonisolated private extension FetchAllUnreadCountsOperation {

	func fetchUnreadCounts(_ database: FMDatabase) -> UnreadCountDictionaryCompletionResult? {
		let sql = "select distinct feedID, count(*) from articles natural join statuses where read=0 group by feedID;"

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return nil
		}

		var unreadCountDictionary = UnreadCountDictionary()
		while resultSet.next() {
			let unreadCount = resultSet.long(forColumnIndex: 1)
			if let feedID = resultSet.string(forColumnIndex: 0) {
				unreadCountDictionary[feedID] = unreadCount
			}
		}
		resultSet.close()

		return .success(unreadCountDictionary)
	}
}
