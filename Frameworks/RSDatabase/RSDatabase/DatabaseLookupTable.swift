//
//  DatabaseLookupTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/5/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Implement a lookup table for a many-to-many relationship.
// Example: CREATE TABLE if not EXISTS authorLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));
// articleID is objectID; authorID is relatedObjectID.

public final class DatabaseLookupTable {

	private let name: String
	private let objectIDKey: String
	private let relatedObjectIDKey: String
	private let relationshipName: String
	private weak var relatedTable: DatabaseTable?
	private let cache: DatabaseLookupTableCache

	public init(name: String, objectIDKey: String, relatedObjectIDKey: String, relatedTable: DatabaseTable, relationshipName: String) {

		self.name = name
		self.objectIDKey = objectIDKey
		self.relatedObjectIDKey = relatedObjectIDKey
		self.relatedTable = relatedTable
		self.relationshipName = relationshipName
		self.cache = DatabaseLookupTableCache(relationshipName)
	}

	public func attachRelationships(to objects: [DatabaseObject], in database: FMDatabase) {
		
		let objectsThatMayHaveRelatedObjects = cache.objectsThatMayHaveRelatedObjects(objects)
		if objectsThatMayHaveRelatedObjects.isEmpty {
			return
		}
		
		attachRelatedObjectsUsingCache(objectsThatMayHaveRelatedObjects, database)
		
		let objectsNeedingFetching = objectsThatMayHaveRelatedObjects.filter { (object) -> Bool in
			return object.relatedObjectsWithName(self.relationshipName) == nil
		}
		if objectsNeedingFetching.isEmpty {
			return
		}
		
		if let lookupTable = fetchLookupTable(objectsNeedingFetching.databaseIDs(), database) {
			attachRelatedObjectsUsingLookupTable(objectsNeedingFetching, lookupTable, database)
		}
		
		cache.update(with: objectsNeedingFetching)
	}
	
	public func saveRelationships(for objects: [DatabaseObject], in database: FMDatabase) {
		
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
		
		removeRelationships(for: objectsWithNoRelationships, database)
		updateRelationships(for: objectsWithRelationships, database)
		
		cache.update(with: objects)
	}
}

private extension DatabaseLookupTable {

	// MARK: Removing
	
	func removeRelationships(for objects: [DatabaseObject], _ database: FMDatabase) {

		let objectIDs = objects.databaseIDs()
		let objectIDsToRemove = objectIDs.subtracting(cache.objectIDsWithNoRelationship)
		if objectIDsToRemove.isEmpty {
			return
		}
		
		database.rs_deleteRowsWhereKey(objectIDKey, inValues: Array(objectIDsToRemove), tableName: name)
	}
	
	// MARK: Saving/Updating
	
	func updateRelationships(for objects: [DatabaseObject], _ database: FMDatabase) {

//		let objectsNeedingUpdate = objects.filter { (object) -> Bool in
//			return !relationshipsMatchCache(object)
//		}
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

	// MARK: Attaching
	
	func attachRelatedObjectsUsingCache(_ objects: [DatabaseObject], _ database: FMDatabase) {
		
		let lookupTable = cache.lookupTableForObjectIDs(objects.databaseIDs())
		attachRelatedObjectsUsingLookupTable(objects, lookupTable, database)
	}
	
	func attachRelatedObjectsUsingLookupTable(_ objects: [DatabaseObject], _ lookupTable: LookupTable, _ database: FMDatabase) {
		
		let relatedObjectIDs = lookupTable.relatedObjectIDs()
		if (relatedObjectIDs.isEmpty) {
			return
		}
		
		guard let relatedObjects = fetchRelatedObjectsWithIDs(relatedObjectIDs, database) else {
			return
		}
		let relatedObjectsDictionary = relatedObjects.dictionary()
		
		for object in objects {
			attachRelatedObjectsToObjectUsingLookupTable(object, relatedObjectsDictionary, lookupTable)
		}
	}

	func attachRelatedObjectsToObjectUsingLookupTable(_ object: DatabaseObject, _ relatedObjectsDictionary: [String: DatabaseObject], _ lookupTable: LookupTable) {
		
		let identifier = object.databaseID
		guard let relatedObjectIDs = lookupTable[identifier], !relatedObjectIDs.isEmpty else {
			return
		}
		let relatedObjects = relatedObjectIDs.flatMap { relatedObjectsDictionary[$0] }
		if !relatedObjects.isEmpty {
			object.setRelatedObjects(relatedObjects, name: relationshipName)
		}
	}
	
	// MARK: Fetching
	
	func fetchRelatedObjectsWithIDs(_ relatedObjectIDs: Set<String>, _ database: FMDatabase) -> [DatabaseObject]? {
		
		guard let relatedObjects = relatedTable?.fetchObjectsWithIDs(relatedObjectIDs, database), !relatedObjects.isEmpty else {
			return nil
		}
		return relatedObjects
	}
	
	func fetchLookupTable(_ objectIDs: Set<String>, _ database: FMDatabase) -> LookupTable? {
		
		guard let lookupValues = fetchLookupValues(objectIDs, database) else {
			return nil
		}
		return LookupTable(lookupValues: lookupValues)
	}

	func fetchLookupValues(_ objectIDs: Set<String>, _ database: FMDatabase) -> Set<LookupValue>? {
		
		guard !objectIDs.isEmpty, let resultSet = database.rs_selectRowsWhereKey(objectIDKey, inValues: Array(objectIDs), tableName: name) else {
			return nil
		}
		return lookupValuesWithResultSet(resultSet)
	}
	
	func lookupValuesWithResultSet(_ resultSet: FMResultSet) -> Set<LookupValue> {
		
		return resultSet.mapToSet(lookupValueWithRow)
	}
	
	func lookupValueWithRow(_ row: FMResultSet) -> LookupValue? {
		
		guard let objectID = row.string(forColumn: objectIDKey) else {
			return nil
		}
		guard let relatedObjectID = row.string(forColumn: relatedObjectIDKey) else {
			return nil
		}
		return LookupValue(objectID: objectID, relatedObjectID: relatedObjectID)
	}
}

struct LookupTable {
	
	private let dictionary: [String: Set<String>] // objectID: Set<relatedObjectID>
	
	init(dictionary: [String: Set<String>]) {
		
		self.dictionary = dictionary
	}
	
	init(lookupValues: Set<LookupValue>) {
		
		var d = [String: Set<String>]()
		
		for lookupValue in lookupValues {
			let objectID = lookupValue.objectID
			let relatedObjectID: String = lookupValue.relatedObjectID
			if d[objectID] == nil {
				d[objectID] = Set([relatedObjectID])
			}
			else {
				d[objectID]!.insert(relatedObjectID)
			}
		}
		
		self.init(dictionary: d)
	}

	func relatedObjectIDs() -> Set<String> {
		
		var ids = Set<String>()
		for (_, relatedObjectIDs) in dictionary {
			ids.formUnion(relatedObjectIDs)
		}
		return ids
	}
	
	subscript(_ objectID: String) -> Set<String>? {
		get {
			return dictionary[objectID]
		}
	}
}

struct LookupValue: Hashable {

	let objectID: String
	let relatedObjectID: String
	let hashValue: Int

	init(objectID: String, relatedObjectID: String) {

		self.objectID = objectID
		self.relatedObjectID = relatedObjectID
		self.hashValue = (objectID + relatedObjectID).hashValue
	}

	static public func ==(lhs: LookupValue, rhs: LookupValue) -> Bool {

		return lhs.objectID == rhs.objectID && lhs.relatedObjectID == rhs.relatedObjectID
	}
}

private final class DatabaseLookupTableCache {

	var objectIDsWithNoRelationship = Set<String>()
	private let relationshipName: String
	private var cachedLookups = [String: Set<String>]() // objectID: Set<relatedObjectID>

	init(_ relationshipName: String) {

		self.relationshipName = relationshipName
	}

	func update(with objects: [DatabaseObject]) {

		var idsWithRelationships = Set<String>()
		var idsWithNoRelationships = Set<String>()
		
		for object in objects {
			let objectID = object.databaseID
			if let relatedObjects = object.relatedObjectsWithName(relationshipName), !relatedObjects.isEmpty {
				idsWithRelationships.insert(objectID)
				self[objectID] = relatedObjects.databaseIDs()
			}
			else {
				idsWithNoRelationships.insert(objectID)
				self[objectID] = nil
			}
		}

		objectIDsWithNoRelationship.subtract(idsWithRelationships)
		objectIDsWithNoRelationship.formUnion(idsWithNoRelationships)
	}

	subscript(_ objectID: String) -> Set<String>? {
		get {
			return cachedLookups[objectID]
		}
		set {
			cachedLookups[objectID] = newValue
		}
	}
	
	func objectsThatMayHaveRelatedObjects(_ objects: [DatabaseObject]) -> [DatabaseObject] {
		
		// Filter out objects that are known to have no related objects
		return objects.filter{ !objectIDsWithNoRelationship.contains($0.databaseID) }
	}
	
	func lookupTableForObjectIDs(_ objectIDs: Set<String>) -> LookupTable {
		
		var d = [String: Set<String>]()
		for objectID in objectIDs {
			if let relatedObjectIDs = self[objectID] {
				d[objectID] = relatedObjectIDs
			}
		}
		return LookupTable(dictionary: d)
	}
}

private extension Set where Element == LookupValue {

	func objectIDs() -> Set<String> {

		return Set<String>(self.map { $0.objectID })
	}
	
	func relatedObjectIDs() -> Set<String> {
		
		return Set<String>(self.map { $0.relatedObjectID })
	}
}

