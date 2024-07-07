//
//  DatabaseRelatedObjectsTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/2/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import FMDB

// Protocol for a database table for related objects — authors and attachments in NetNewsWire, for instance.

public protocol DatabaseRelatedObjectsTable {

	var name: String { get }
	var databaseIDKey: String { get}
	var cache: DatabaseObjectCache { get }
	
	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]?
	func objectsWithResultSet(_ resultSet: FMResultSet) -> [DatabaseObject]
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject?

	func save(_ objects: [DatabaseObject], in database: FMDatabase)
}

public extension DatabaseRelatedObjectsTable {

	// MARK: Default implementations

	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]? {

		if databaseIDs.isEmpty {
			return nil
		}

		var cachedObjects = [DatabaseObject]()
		var databaseIDsToFetch = Set<String>()

		for databaseID in databaseIDs {
			if let cachedObject = cache[databaseID] {
				cachedObjects += [cachedObject]
			}
			else {
				databaseIDsToFetch.insert(databaseID)
			}
		}

		if databaseIDsToFetch.isEmpty {
			return cachedObjects
		}

		guard let resultSet = database.selectRowsWhere(key: databaseIDKey, equalsAnyValue: Array(databaseIDsToFetch), tableName: name) else {
			return cachedObjects
		}

		let fetchedDatabaseObjects = objectsWithResultSet(resultSet)
		cache.add(fetchedDatabaseObjects)

		return cachedObjects + fetchedDatabaseObjects
	}

	func objectsWithResultSet(_ resultSet: FMResultSet) -> [DatabaseObject] {

		return resultSet.compactMap(objectWithRow)
	}

	func save(_ objects: [DatabaseObject], in database: FMDatabase) {

		// Objects in cache must already exist in database. Filter them out.
		let objectsToSave = objects.filter { (object) -> Bool in
			if let _ = cache[object.databaseID] {
				return false
			}
			return true
		}

		cache.add(objectsToSave)
		if let databaseDictionaries = objectsToSave.databaseDictionaries() {
			database.insertRows(databaseDictionaries, insertType: .orIgnore, tableName: name)
		}
	}

}
