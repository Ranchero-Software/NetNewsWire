//
//  FetchFeedUnreadCountOperation.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 1/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase

/// Fetch the unread count for a single feed.
public final class FetchFeedUnreadCountOperation: MainThreadOperation {

	public var unreadCount: Int?
	public let feedID: String

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String?
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private let queue: DatabaseQueue
	private let cutoffDate: Date

	init(feedID: String, databaseQueue: DatabaseQueue, cutoffDate: Date) {
		self.feedID = feedID
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
				self.fetchUnreadCount(database)
			case .failure:
				self.informOperationDelegateOfCompletion()
			}
		}
	}
}

private extension FetchFeedUnreadCountOperation {

	func fetchUnreadCount(_ database: FMDatabase) {
		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0 and (starred=1 or dateArrived>?);"

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: [feedID, cutoffDate]) else {
			informOperationDelegateOfCompletion()
			return
		}
		if isCanceled {
			informOperationDelegateOfCompletion()
			return
		}

		if resultSet.next() {
			unreadCount = resultSet.long(forColumnIndex: 0)
		}
		resultSet.close()

		informOperationDelegateOfCompletion()
	}
}
