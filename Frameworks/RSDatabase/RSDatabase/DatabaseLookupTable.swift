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
	private let cache: DatabaseLookupTableCache

	public init(name: String, primaryKey: String, foreignKey: String, relatedTable: DatabaseTable, relationshipName: String) {

		self.name = name
		self.primaryKey = primaryKey
		self.foreignKey = foreignKey
		self.relatedTable = relatedTable
		self.relationshipName = relationshipName
		self.cache = DatabaseLookupTableCache(relationshipName)
	}

	public func attachRelationships(to objects: [DatabaseObject], database: FMDatabase) {
		
		guard let lookupTable = fetchLookupTable(objects.databaseIDs(), database) else {
			return;
		}
		attachRelationshipsUsingLookupTable(to: objects, lookupTable: lookupTable, database: database)
	}
	
	public func saveRelationships(for objects: [DatabaseObject], database: FMDatabase) {
		
		var objectsWithNoRelationships = [DatabaseObject]()
		var objectsWithRelationships = [DatabaseObject]()

		for object in objects {
			if let relatedObjects = object.relatedObjectsWithName(relationshipName), !relatedObjects.isEmpty {
				objectsWithRelationships += [object]
			}
			else {
				objectsWithNoRelationships += [object]
			}
		}
		
		removeRelationships(for: objectsWithNoRelationships, database: database)
		updateRelationships(for: objectsWithRelationships, database: database)
	}
}

private extension DatabaseLookupTable {

	func removeRelationships(for objects: [DatabaseObject], database: FMDatabase) {

		removeLookupsForForeignIDs(objects.databaseIDs(), database)
	}

	func updateRelationships(for objects: [DatabaseObject], database: FMDatabase) {

		let objectsNeedingUpdate = objects.filter { (object) -> Bool in
			return !relationshipsMatchCache(object)
		}
	}

	func relationshipsMatchCache(_ object: DatabaseObject) -> Bool {

		let relationships = object.relatedObjectsWithName(relationshipName)
		let cachedRelationshipIDs = cache[object.databaseID]

		if let relationships = relationships {
			if let cachedRelationshipIDs = cachedRelationshipIDs {
				return relationships.databaseIDs() == cachedRelationshipIDs
			}
			return false // cachedRelationshipIDs == nil, relationships != nil
		}
		else { // relationships == nil
			if let cachedRelationshipIDs = cachedRelationshipIDs {
				return !cachedRelationshipIDs.isEmpty
			}
			return true // both nil
		}
	}

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
		guard let lookupValues = fetchLookupValues(foreignIDsToLookup, database) else {
			return nil
		}
		updateCache(lookupValues, foreignIDsToLookup)
		
		return LookupTable(lookupValues)
	}

	func cacheForeignIDsWithNoRelationships(_ foreignIDs: Set<String>) {

		foreignIDsWithNoRelationship.formUnion(foreignIDs)
		for foreignID in foreignIDs {
			cache[foreignID] = nil
		}
	}

	func updateCache(_ lookupValues: Set<LookupValue>, _ foreignIDs: Set<String>) {
		
		// Maintain foreignIDsWithNoRelationship.
		// If a relationship exist, remove the foreignID from foreignIDsWithNoRelationship.
		// If a relationship does not exist, add the foreignID to foreignIDsWithNoRelationship.
		
		let foreignIDsWithRelationship = lookupValues.foreignIDs()

		let foreignIDs
		for foreignID in foreignIDs {
			if !foreignIDsWithRelationship.contains(foreignID) {
				foreignIDsWithNoRelationship.insert(foreignID)
			}
		}
	}
	
	func removeLookupsForForeignIDs(_ foreignIDs: Set<String>, _ database: FMDatabase) {
		
		let foreignIDsToRemove = foreignIDs.subtracting(foreignIDsWithNoRelationship)
		if foreignIDsToRemove.isEmpty {
			return
		}
		
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

struct LookupTable {
	
	private let dictionary: [String: Set<LookupValue>]
	
	init(_ lookupValues: Set<LookupValue>) {
		
		var d = [String: Set<LookupValue>]()
		
		for lookupValue in lookupValues {
			let foreignID = lookupValue.foreignID
			if d[foreignID] == nil {
				d[foreignID] = Set([lookupValue])
			}
			else {
				d[foreignID]!.insert(lookupValue)
			}
		}
		
		self.dictionary = d
	}

	func primaryIDs() -> Set<String> {
		
		var ids = Set<String>()
		for (_, lookupValues) in dictionary {
			ids.formUnion(lookupValues.primaryIDs())
		}
		return ids
	}
	
	subscript(_ foreignID: String) -> Set<LookupValue>? {
		get {
			return dictionary[foreignID]
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
		self.hashValue = (primaryID + foreignID).hashValue
	}

	static public func ==(lhs: LookupValue, rhs: LookupValue) -> Bool {

		return lhs.primaryID == rhs.primaryID && lhs.foreignID == rhs.foreignID
	}
}

private final class DatabaseLookupTableCache {

	private let relationshipName: String
	private var foreignIDsWithNoRelationship = Set<String>()
	private var cachedLookups = [String: Set<String>]() // foreignID: Set<primaryID>

	init(_ relationshipName: String) {

		self.relationshipName = relationshipName
	}

	func updateCacheWithIDsWithNoRelationship(_ foreignIDs: Set<String>) {

		foreignIDsWithNoRelationship.formUnion(foreignIDs)
		for foreignID in foreignIDs {
			cachedLookups[foreignID] = nil
		}
	}

	func updateCacheWithObjects(_ object: [DatabaseObject]) {

		var foreignIDsWithRelationship = Set<String>()

		for object in objects {

			if let relatedObjects = object.relatedObjectsWithName, !relatedObjects.isEmpty {
				foreignIDsWithRelationship.insert(object.databaseID)
			}
			else {
				updateCacheWithIDsWithNoRelationship(objects.databaseIDs())
			}
		}

		foreignIDsWithNoRelationship.subtract(foreignIDsWithRelationships)
	}

	func foreignIDHasNoRelationship(_ foreignID: String) -> Bool {

		return foreignIDsWithNoRelationship.contains(foreignID)
	}

	func relationshipIDsForForeignID(_ foreignID: String) -> Set<String>? {

		return cachedLookups[foreignID]
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

