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
import RSDatabaseObjC

/// Fetch the unread count for a single feed.
public final class FetchFeedUnreadCountOperation: MainThreadOperation, @unchecked Sendable {

	var result: SingleUnreadCountResult?

	private let queue: DatabaseQueue
	private let cutoffDate: Date
	private let feedID: String

	init(feedID: String, databaseQueue: DatabaseQueue, cutoffDate: Date) {
		self.feedID = feedID
		self.queue = databaseQueue
		self.cutoffDate = cutoffDate
		super.init(name: "FetchFeedUnreadCountOperation")
	}

	@MainActor public override func run() {
		queue.runInDatabase { databaseResult in
			if self.isCanceled {
				self.didComplete()
				return
			}

			switch databaseResult {
			case .success(let database):
				self.fetchUnreadCount(database)
			case .failure:
				self.result = .failure(.isSuspended)
			}

			self.didComplete()
		}
	}
}

private extension FetchFeedUnreadCountOperation {

	func fetchUnreadCount(_ database: FMDatabase) {
		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0;"

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: [feedID]) else {
			return
		}

		if resultSet.next() {
			let unreadCount = resultSet.long(forColumnIndex: 0)
			result = .success(unreadCount)
		}
		resultSet.close()
	}
}
