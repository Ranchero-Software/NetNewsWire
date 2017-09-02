//
//  DatabaseRelatedObjectsTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/2/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DatabaseRelatedObjectsTable: DatabaseTable {

	var databaseIDKey: String { get}

	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]
	func objectsWithResultSet(_ resultSet: FMResultSet) -> [DatabaseObject]
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject?

	func save(_ objects: [DatabaseObject], in database: FMDatabase)
}

public extension DatabaseRelatedObjectsTable {


}
