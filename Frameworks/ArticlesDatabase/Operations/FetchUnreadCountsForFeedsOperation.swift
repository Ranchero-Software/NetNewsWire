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

/// Fetch the unread counts for a number of feeds.
public final class FetchUnreadCountsForFeedsOperation: MainThreadOperation {

	public var unreadCountDictionary: UnreadCountDictionary?
	public let feedIDs: Set<String>

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String?
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private let queue: DatabaseQueue
	private let cutoffDate: Date

	init(feedIDs: Set<String>, databaseQueue: DatabaseQueue, cutoffDate: Date) {
		self.feedIDs = feedIDs
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

private extension FetchUnreadCountsForFeedsOperation {

	func fetchUnreadCounts(_ database: FMDatabase) {
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select distinct feedID, count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 and userDeleted=0 and (starred=1 or dateArrived>?) group by feedID;"

		var parameters = [Any]()
		parameters += Array(feedIDs) as [Any]
		parameters += [cutoffDate] as [Any]

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			informOperationDelegateOfCompletion()
			return
		}
		if isCanceled {
			informOperationDelegateOfCompletion()
			return
		}

		var d = UnreadCountDictionary()
		while resultSet.next() {
			if isCanceled {
				resultSet.close()
				informOperationDelegateOfCompletion()
				return
			}
			let unreadCount = resultSet.long(forColumnIndex: 1)
			if let webFeedID = resultSet.string(forColumnIndex: 0) {
				d[webFeedID] = unreadCount
			}
		}
		resultSet.close()

		unreadCountDictionary = d
		informOperationDelegateOfCompletion()
	}
}
