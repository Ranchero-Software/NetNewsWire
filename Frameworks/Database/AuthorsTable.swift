//
//  AuthorsTable.swift
//  Database
//
//  Created by Brent Simmons on 7/13/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data

final class AuthorsTable: DatabaseTable {

	let name: String
	let queue: RSDatabaseQueue

	init(name: String, queue: RSDatabaseQueue) {

		self.name = name
		self.queue = queue
	}

	var cachedAuthors = [String: Author]()
	
	func cachedAuthor(_ databaseID: String) -> Author? {
		
		return cachedAuthors[databaseID]
	}
	
	func cacheAuthor(_ author: Author) {
		
		cachedAuthors[author.databaseID] = author
	}
	
	func authorWithRow(_ row: FMResultSet) -> Author? {
		
		let databaseID = row.string(forColumn: DatabaseKey.databaseID)
		if let author = cachedAuthor(databaseID) {
			return author
		}
		
		guard let author = Author(row: row) else {
			return nil
		}
		
		cacheAuthor(author)
		return author
	}
}
