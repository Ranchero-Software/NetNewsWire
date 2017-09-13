//
//  DatabaseRelatedObjectsTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/2/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Protocol for a database table for related objects — authors, tags, and attachments in Evergreen, for instance.

public protocol DatabaseRelatedObjectsTable: DatabaseTable {

	var databaseIDKey: String { get}

	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]?
	func objectsWithResultSet(_ resultSet: FMResultSet) -> [DatabaseObject]
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject?

	func save(_ objects: [DatabaseObject], in database: FMDatabase)
}

public extension DatabaseRelatedObjectsTable {

	// MARK: Default implementations

	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]? {

		guard let resultSet = selectRowsWhere(key: databaseIDKey, inValues: Array(databaseIDs), in: database) else {
			return nil
		}
		return objectsWithResultSet(resultSet)
	}

	func objectsWithResultSet(_ resultSet: FMResultSet) -> [DatabaseObject] {

		return resultSet.flatMap(objectWithRow)
	}
}
