//
//  LookupTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/5/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Implement a lookup table for a many-to-many relationship.
// Example: CREATE TABLE if not EXISTS authorLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));
// authorID is primaryKey; articleID is foreignKey.
//
// foreignIDsWithNoRelationship: caches the foreignIDs where it’s known that there’s no relationship.
// lookupsByForeignID: caches the LookupValues for a foreignID.

public typealias LookupTableDictionary = [String: Set<LookupValue>] // key is foreignID

public final class LookupTable: DatabaseTable {

	public let name: String
	let primaryKey: String
	let foreignKey: String
	private var foreignIDsWithNoRelationship = Set<String>()
	private var lookupsByForeignID = LookupTableDictionary()

	public init(name: String, primaryKey: String, foreignKey: String) {

		self.name = name
		self.primaryKey = primaryKey
		self.foreignKey = foreignKey
	}

	public func fetchObjectsWithIDs(_ databaseIDs: Set<String>, _ database: FMDatabase) -> [DatabaseObject] {
		
	}

	public func fetchLookupTableDictionary(_ foreignIDs: Set<String>, _ database: FMDatabase) -> LookupTableDictionary? {

		let foreignIDsToLookup = foreignIDs.subtracting(foreignIDsWithNoRelationship)
		if foreignIDsToLookup.isEmpty {
			return nil
		}

		var lookupValues = Set<LookupValue>()
		var foreignIDsToFetchFromDatabase = Set<String>()

		// Pull from cache.
		for oneForeignID in foreignIDsToLookup {
			if let cachedLookups = lookupsByForeignID[oneForeignID] {
				lookupValues.formUnion(cachedLookups)
			}
			else {
				foreignIDsToFetchFromDatabase.insert(oneForeignID)
			}
		}

		if !foreignIDsToFetchFromDatabase.isEmpty {
			if let resultSet = database.rs_selectRowsWhereKey(foreignKey, inValues: Array(foreignIDsToLookup), tableName: name) {
				lookupValues.formUnion(lookupValuesWithResultSet(resultSet))
			}
		}

		cacheNotFoundForeignIDs(lookupValues, foreignIDsToFetchFromDatabase)
		cacheLookupValues(lookupValues)

		return lookupTableDictionary(with: lookupValues)
	}

	public func attachRelationships(to objects: [DatabaseObject], table: DatabaseTable, lookupTableDictionary: LookupTableDictionary, relationshipName: String, database: FMDatabase) {
		
		let primaryIDs = primaryIDsInLookupTableDictionary(lookupTableDictionary)
		if (primaryIDs.isEmpty) {
			return
		}
		
		let relatedObjects: [DatabaseObject] = table.fetchObjectsWithIDs(primaryIDs, database)
		if relatedObjects.isEmpty {
			return
		}
		
		let relatedObjectsDictionary = relatedObjects.dictionary()
		
		for object in objects {
			let identifier = object.databaseID
			if let lookupValues = lookupTableDictionary[identifier], !lookupValues.isEmpty {
				let primaryIDs = lookupValues.primaryIDs()
				let oneObjectRelatedObjects = primaryIDs.flatMap{ (primaryID) -> DatabaseObject? in
					return relatedObjectsDictionary[primaryID]
				}
				object.attachRelationshipWithObjects(oneObjectRelatedObjects, name: relationshipName)
			}
		}
	}
	
	func primaryIDsInLookupTableDictionary(_ lookupTableDictionary: LookupTableDictionary) -> Set<String> {
	
		var primaryIDs = Set<String>()
		
		for (_, lookupValues) in lookupTableDictionary {
			primaryIDs.formUnion(lookupValues.primaryIDs())
		}
		
		return primaryIDs
	}
	
	public func removeLookupsForForeignIDs(_ foreignIDs: Set<String>, _ database: FMDatabase) {

		let foreignIDsToRemove = foreignIDs.subtracting(foreignIDsWithNoRelationship)
		if foreignIDsToRemove.isEmpty {
			return
		}

		for oneForeignID in foreignIDsToRemove {
			lookupsByForeignID[oneForeignID] = nil
		}
		foreignIDsWithNoRelationship.formUnion(foreignIDsToRemove)

		database.rs_deleteRowsWhereKey(foreignKey, inValues: Array(foreignIDsToRemove), tableName: name)
	}
}

private extension LookupTable {

	func addToLookupTableDictionary(_ lookupValues: Set<LookupValue>, _ table: inout LookupTableDictionary) {

		for lookupValue in lookupValues {
			let foreignID = lookupValue.foreignID
			let primaryID = lookupValue.primaryID
			if table[foreignID] == nil {
				table[foreignID] = Set([primaryID])
			}
			else {
				table[foreignID]!.insert(primaryID)
			}
		}
	}

	func lookupTableDictionary(with lookupValues: Set<LookupValue>) -> LookupTableDictionary {

		var d = LookupTableDictionary()
		addToLookupTableDictionary(lookupValues, &d)
		return d
	}

	func cacheLookupValues(_ lookupValues: Set<LookupValue>) {

		addToLookupTableDictionary(lookupValues, &lookupsByForeignID)
	}

	func cacheNotFoundForeignIDs(_ lookupValues: Set<LookupValue>, _ foreignIDs: Set<String>) {

		// Note where nothing was found, and cache the foreignID in foreignIDsWithNoRelationship.

		let foundForeignIDs = Set(lookupValues.map { $0.foreignID })
		for foreignID in foreignIDs {
			if !foundForeignIDs.contains(foreignID) {
				foreignIDsWithNoRelationship.insert(foreignID)
			}
		}
	}

	func lookupValuesWithResultSet(_ resultSet: FMResultSet) -> Set<LookupValue> {

		return resultSet.mapToSet(lookupValueWithRow)
	}

	func lookupValueWithRow(_ row: FMResultSet) -> LookupValue? {

		guard let primaryID = row.string(forColumn: primaryKey) else {
			return nil
		}
		guard let foreignID = row.string(forColumn: foreignKey) else {
			return nil
		}
		return LookupValue(primaryID: primaryID, foreignID: foreignID)
	}

}

public struct LookupValue: Hashable {

	public let primaryID: String
	public let foreignID: String
	public let hashValue: Int

	init(primaryID: String, foreignID: String) {

		self.primaryID = primaryID
		self.foreignID = foreignID
		self.hashValue = "\(primaryID)\(foreignID)".hashValue
	}

	static public func ==(lhs: LookupValue, rhs: LookupValue) -> Bool {

		return lhs.primaryID == rhs.primaryID && lhs.foreignID == rhs.foreignID
	}
}

private extension Set where Element == LookupValue {
	
	func primaryIDs() -> Set<String> {
		
		return Set(map { $0.primaryID })
	}
}
