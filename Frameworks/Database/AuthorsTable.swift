//
//  AuthorsTable.swift
//  Database
//
//  Created by Brent Simmons on 7/13/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

final class AuthorsTable: DatabaseTable {

	let name: String
	let queue: RSDatabaseQueue
	private let cache = ObjectCache<Author>(keyPathForID: \Author.databaseID)

	init(name: String, queue: RSDatabaseQueue) {

		self.name = name
		self.queue = queue
	}

	func authorWithRow(_ row: FMResultSet) -> Author? {

		// Since:
		// 1. anything to do with an FMResultSet runs inside the database serial queue, and
		// 2. the cache is referenced only within this method,
		// this is safe.

		guard let databaseID = row.string(forColumn: DatabaseKey.databaseID) else {
			return nil
		}

		if let cachedAuthor = cache[databaseID] {
			return cachedAuthor
		}
		
		guard let author = Author(row: row) else {
			return nil
		}

		cache[databaseID] = author
		return author
	}
}

