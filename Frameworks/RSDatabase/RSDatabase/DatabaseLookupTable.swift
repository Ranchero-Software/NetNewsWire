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


public final class DatabaseLookupTable {

	public let name: String
	let primaryKey: String
	let foreignKey: String
	private var foreignIDsWithNoRelationship = Set<String>()
	private var cache = LookupTable(Set<LookupValue>())

	public init(name: String, primaryKey: String, foreignKey: String) {

		self.name = name
		self.primaryKey = primaryKey
		self.foreignKey = foreignKey
	}

	public func fetchLookupTable(_ foreignIDs: Set<String>, _ database: FMDatabase) -> LookupTable? {

		let foreignIDsToLookup = foreignIDs.subtracting(foreignIDsWithNoRelationship)
		if foreignIDsToLookup.isEmpty {
			return nil
		}

		var lookupValues = Set<LookupValue>()
		var foreignIDsToFetchFromDatabase = Set<String>()

		// Pull from cache.
		for foreignID in foreignIDsToLookup {
			if let cachedLookups = cache[foreignID] {
				lookupValues.formUnion(cachedLookups)
			}
			else {
				foreignIDsToFetchFromDatabase.insert(foreignID)
			}
		}

		// Fetch from database.
		if let fetchedLookupValues = fetchLookupValues(foreignIDsToFetchFromDatabase, database) {
			lookupValues.formUnion(fetchedLookupValues)
		}

		// Maintain cache.
		cacheNotFoundForeignIDs(lookupValues, foreignIDsToFetchFromDatabase)
		cache.addLookupValues(fetchedLookupValues)

		return LookupTable(lookupValues: lookupValues)
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
			cache[oneForeignID] = nil
		}
		foreignIDsWithNoRelationship.formUnion(foreignIDsToRemove)

		database.rs_deleteRowsWhereKey(foreignKey, inValues: Array(foreignIDsToRemove), tableName: name)
	}
}

private extension DatabaseLookupTable {

	func fetchLookupValues(_ foreignIDs: Set<String>, _ database: FMDatabase) -> Set<LookupValue>? {
		
		guard !foreignIDs.isEmpty, let resultSet = database.rs_selectRowsWhereKey(foreignKey, inValues: Array(foreignIDsToLookup), tableName: name) else {
			return nil
		}
		return lookupValuesWithResultSet(resultSet)
	}
	
	func addToLookupTableDictionary(_ lookupValues: Set<LookupValue>, _ table: inout LookupTableDictionary) {

		for lookupValue in lookupValues {
			let foreignID = lookupValue.foreignID
			if table[foreignID] == nil {
				table[foreignID] = Set([lookupValue])
			}
			else {
				table[foreignID]!.insert(lookupValue)
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

		let foundForeignIDs = lookupValues.foreignIDs()
		var foreignIDsToRemove = Set<String>()
		for foreignID in foreignIDs {
			if !foundForeignIDs.contains(foreignID) {
				foreignIDsWithNoRelationship.insert(foreignID)
				foreignIDsToRemove.insert(foreignID)
			}
		}
		
		cache.removeLookupValuesForForeignIDs(foreignIDsToRemove)
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

final class LookupTable {
	
	var lookupValues: Set<LookupValue>
	var dictionary = [String: Set<LookupValues>]()
	
	init(lookupValues: Set<LookupValue>) {
		
		self.lookupValues = lookupValues
		addLookupValuesToDictionary()
	}
	
	func primaryIDs() -> Set<String> {
		
		return lookupValues.primaryIDs()
	}
	
	func addLookupValues(_ values: Set<LookupValue>) {
		
		lookupValues.formUnion(values)
		addLookupValuesToDictionary(values)
	}
	
	func removeLookupValuesForForeignIDs(_ foreignIDs: Set<String>) {
		
		for foreignID in foreignIDs {
			self[foreignID] = nil
		}
		
		let lookupValuesToRemove = lookupValues.filter { (lookupValue) -> Bool in
			foreignIDs.contains(lookupValue.foreignID)
		}
		lookupValues.subtract(lookupValuesToRemove)
	}
	
	func addLookupValuesToDictionary(_ values: Set<LookupValue>) {

		for lookupValue in values {
			let foreignID = lookupValue.foreignID
			if self[foreignID] == nil {
				self[foreignID] = Set([lookupValue])
			}
			else {
				self[foreignID]!.insert(lookupValue)
			}
		}
	}
	
	subscript(_ foreignID: String) -> Set<LookupValue>? {
		get {
			return dictionary[foreignID]
		}
		set {
			dictionary[foreignID] = newValue
		}
	}
}

struct LookupValue: Hashable {

	let primaryID: String
	let foreignID: String
	let hashValue: Int

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

		return Set<String>(self.map { $0.primaryID })
	}
	
	func foreignIDs() -> Set<String> {
		
		return Set<String>(self.map { $0.foreignID })
	}
}

