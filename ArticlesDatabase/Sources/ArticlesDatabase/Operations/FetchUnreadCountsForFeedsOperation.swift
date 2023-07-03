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
public final class FetchUnreadCountsForFeedsOperation: MainThreadOperation {

	var result: UnreadCountDictionaryCompletionResult = .failure(.isSuspended)

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "FetchUnreadCountsForFeedsOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private let queue: DatabaseQueue
	private let feedIDs: Set<String>

	init(feedIDs: Set<String>, databaseQueue: DatabaseQueue) {
		self.feedIDs = feedIDs
		self.queue = databaseQueue
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

private extension FetchUnreadCountsForFeedsOperation {

	func fetchUnreadCounts(_ database: FMDatabase) {
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select distinct feedID, count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 group by feedID;"

		let parameters = Array(feedIDs) as [Any]

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			informOperationDelegateOfCompletion()
			return
		}
		if isCanceled {
			resultSet.close()
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
			if let feedID = resultSet.string(forColumnIndex: 0) {
				unreadCountDictionary[feedID] = unreadCount
			}
		}
		resultSet.close()

		result = .success(unreadCountDictionary)
		informOperationDelegateOfCompletion()
	}
}
