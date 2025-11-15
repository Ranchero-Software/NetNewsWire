//
//  FetchUnreadCountsForFeedsOperation.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 2/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC

/// Fetch the unread counts for a number of feeds.
public final class FetchUnreadCountsForFeedsOperation: MainThreadOperation, @unchecked Sendable {
	var result: UnreadCountDictionaryCompletionResult?

	private let queue: DatabaseQueue
	private let feedIDs: Set<String>

	init(feedIDs: Set<String>, databaseQueue: DatabaseQueue) {
		self.feedIDs = feedIDs
		self.queue = databaseQueue
		super.init(name: "FetchUnreadCountsForFeedsOperation")
	}

	@MainActor public override func run() {
		queue.runInDatabase { databaseResult in
			if self.isCanceled {
				self.didComplete()
				return
			}

			switch databaseResult {
			case .success(let database):
				if let unreadCountDictionary = self.fetchUnreadCounts(database) {
					self.result = .success(unreadCountDictionary)
				}
			case .failure:
				self.result = .failure(.isSuspended)
			}

			self.didComplete()
		}
	}
}

nonisolated private extension FetchUnreadCountsForFeedsOperation {

	func fetchUnreadCounts(_ database: FMDatabase) -> UnreadCountDictionary? {
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select distinct feedID, count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 group by feedID;"

		let parameters = Array(feedIDs) as [Any]

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return nil
		}
		defer {
			resultSet.close()
		}

		var unreadCountDictionary = UnreadCountDictionary()
		while resultSet.next() {
			let unreadCount = resultSet.long(forColumnIndex: 1)
			if let feedID = resultSet.string(forColumnIndex: 0) {
				unreadCountDictionary[feedID] = unreadCount
			}
		}

		return unreadCountDictionary
	}
}
