//
//  SyncStatusTable.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase

final class SyncStatusTable: DatabaseTable {
	
	let name = DatabaseTableName.syncStatus
	private let queue: RSDatabaseQueue
	
	init(queue: RSDatabaseQueue) {
		self.queue = queue
	}

	func insertStatuses(_ statuses: [SyncStatus]) {
		self.queue.update { database in
			let statusArray = statuses.map { $0.databaseDictionary()! }
			self.insertRows(statusArray, insertType: .orReplace, in: database)
		}
	}
	
}
