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

	private let name: String
	private let primaryKey: String
	private let foreignKey: String
	private let relationshipName: String
	private weak var relatedTable: DatabaseTable?
	private var foreignIDsWithNoRelationship = Set<String>()
	private var cache = LookupTable(Set<LookupValue>())

	public init(name: String, primaryKey: String, foreignKey: String, relatedTable: DatabaseTable, relationshipName: String) {

		self.name = name
		self.primaryKey = primaryKey
		self.foreignKey = foreignKey
		self.relatedTable = relatedTable
		self.relationshipName = relationshipName
	}

	public func attachRelationships(to objects: [DatabaseObject], database: FMDatabase) {
		
		guard !objects.isEmpty, let lookupTable = fetchLookupTable(objects.databaseIDs(), database) else {
			return;
		}
		attachRelationshipsUsingLookupTable(to: objects, lookupTable: lookupTable, database: database)
	}
	
	public func saveRelationships(for objects: [DatabaseObject], relationshipName: String, database: FMDatabase) {
		
		
	}
	
	public func removeRelationships(for objects: [DatabaseObject], relationshipName: String, database: FMDatabase) {
		
		removeLookupsForForeignIDs(objects.databaseIDs(), database)
	}
	
}

private extension DatabaseLookupTable {

	func attachRelationshipsUsingLookupTable(to objects: [DatabaseObject], lookupTable: LookupTable, database: FMDatabase) {
		
		let primaryIDs = lookupTable.primaryIDs()
		if (primaryIDs.isEmpty) {
			return
		}
		
		guard let relatedObjects: [DatabaseObject] = relatedTable?.fetchObjectsWithIDs(primaryIDs, database), !relatedObjects.isEmpty else {
			return
		}
		
		let relatedObjectsDictionary = relatedObjects.dictionary()
		
		for object in objects {
			let identifier = object.databaseID
			if let lookupValues = lookupTable[identifier], !lookupValues.isEmpty {
				let primaryIDs = lookupValues.primaryIDs()
				let oneObjectRelatedObjects = primaryIDs.flatMap{ (primaryID) -> DatabaseObject? in
					return relatedObjectsDictionary[primaryID]
				}
				object.setRelatedObjects(oneObjectRelatedObjects, name: relationshipName)
			}
		}
	}

	func fetchLookupTable(_ foreignIDs: Set<String>, _ database: FMDatabase) -> LookupTable? {
		
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
		let fetchedLookupValues = fetchLookupValues(foreignIDsToFetchFromDatabase, database)
		if let fetchedLookupValues = fetchedLookupValues {
			lookupValues.formUnion(fetchedLookupValues)
			cache.addLookupValues(fetchedLookupValues)
		}
		
		// Maintain cache.
		cacheNotFoundForeignIDs(lookupValues, foreignIDsToFetchFromDatabase)
		
		return LookupTable(lookupValues)
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
	
	func removeLookupsForForeignIDs(_ foreignIDs: Set<String>, _ database: FMDatabase) {
		
		let foreignIDsToRemove = foreignIDs.subtracting(foreignIDsWithNoRelationship)
		if foreignIDsToRemove.isEmpty {
			return
		}
		
		cache.removeLookupValuesForForeignIDs(foreignIDsToRemove)
		foreignIDsWithNoRelationship.formUnion(foreignIDsToRemove)
		
		database.rs_deleteRowsWhereKey(foreignKey, inValues: Array(foreignIDsToRemove), tableName: name)
	}
	
	func fetchLookupValues(_ foreignIDs: Set<String>, _ database: FMDatabase) -> Set<LookupValue>? {
		
		guard !foreignIDs.isEmpty, let resultSet = database.rs_selectRowsWhereKey(foreignKey, inValues: Array(foreignIDs), tableName: name) else {
			return nil
		}
		return lookupValuesWithResultSet(resultSet)
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

private class LookupTable {
	
	var dictionary = [String: Set<LookupValue>]()
	
	init(_ lookupValues: Set<LookupValue>) {
		
		addLookupValues(lookupValues)
	}
	
	func primaryIDs() -> Set<String> {
		
		var ids = Set<String>()
		for (_, lookupValues) in dictionary {
			ids.formUnion(lookupValues.primaryIDs())
		}
		return ids
	}
	
	func addLookupValues(_ values: Set<LookupValue>) {
		
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
	
	func removeLookupValuesForForeignIDs(_ foreignIDs: Set<String>) {
		
		for foreignID in foreignIDs {
			self[foreignID] = nil
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

private struct LookupValue: Hashable {

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

