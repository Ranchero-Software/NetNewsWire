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
	private let relatedTable: DatabaseRelatedObjectsTable
	private let cache: DatabaseLookupTableCache
	private var objectIDsWithNoRelatedObjects = Set<String>()
	
	public init(name: String, objectIDKey: String, relatedObjectIDKey: String, relatedTable: DatabaseRelatedObjectsTable, relationshipName: String) {

		self.name = name
		self.objectIDKey = objectIDKey
		self.relatedObjectIDKey = relatedObjectIDKey
		self.relatedTable = relatedTable
		self.relationshipName = relationshipName
		self.cache = DatabaseLookupTableCache(relationshipName)
	}

	public func fetchRelatedObjects(for objectIDs: Set<String>, in database: FMDatabase) -> RelatedObjectsLookupTable? {
	
		let objectIDsThatMayHaveRelatedObjects = objectIDs.subtracting(objectIDsWithNoRelatedObjects)
		if objectIDsThatMayHaveRelatedObjects.isEmpty {
			return nil
		}
	
		guard let lookupTable = fetchLookupTable(objectIDsThatMayHaveRelatedObjects, database) else {
			objectIDsWithNoRelatedObjects.formUnion(objectIDsThatMayHaveRelatedObjects)
			return nil
		}
		
		if let relatedObjects = fetchRelatedObjectsReferencedByLookupTable(LookupTable, database) {
			
			let relatedObjectsDictionary = relatedObjectsDictionary(lookupTable, relatedObjects)
			
			let objectIDsWithNoFetchedRelatedObjects = objectIDsThatMayHaveRelatedObjects.subtracting(Set(relatedObjectsDictionary.keys))
			objectIDsWithNoRelatedObjects.formUnion(objectIDsWithNoFetchedRelatedObjects)
			
			return relatedObjectsDictionary
		}
		
		return nil
	}
	
	public func attachRelatedObjects(to objects: [DatabaseObject], in database: FMDatabase) {
		
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
	
	public func saveRelatedObjects(for objects: [DatabaseObject], in database: FMDatabase) {
		
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

// MARK: - Private

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
	
	func deleteLookups(for objectID: String, _ relatedObjectIDs: Set<String>, _ database: FMDatabase) {
		
		guard !relatedObjectIDs.isEmpty else {
			assertionFailure("deleteLookups: expected non-empty relatedObjectIDs")
			return
		}
		
		// delete from authorLookup where articleID=? and authorID in (?,?,?)
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(relatedObjectIDs.count))!
		let sql = "delete from \(name) where \(objectIDKey)=? and \(relatedObjectIDKey) in \(placeholders)"
		
		let parameters: [Any] = [objectID] + Array(relatedObjectIDs)
		let _ = database.executeUpdate(sql, withArgumentsIn: parameters)
	}
	
	// MARK: Saving/Updating
	
	func updateRelationships(for objects: [DatabaseObject], _ database: FMDatabase) {

		let objectsNeedingUpdate = objects.filter { !relatedObjectIDsMatchesCache($0) }
		if objectsNeedingUpdate.isEmpty {
			return
		}
		
		if let lookupTable = fetchLookupTable(objectsNeedingUpdate.databaseIDs(), database) {
			for object in objectsNeedingUpdate {
				syncRelatedObjectsAndLookupTable(object, lookupTable, database)
			}
		}
		
		// Save the actual related objects.
		
		let relatedObjectsToSave = uniqueArrayOfRelatedObjects(with: objectsNeedingUpdate)
		if relatedObjectsToSave.isEmpty {
			assertionFailure("updateRelationships: expected relatedObjectsToSave would not be empty. This should be unreachable.")
			return
		}
		
		relatedTable.save(relatedObjectsToSave, in: database)
	}

	func uniqueArrayOfRelatedObjects(with objects: [DatabaseObject]) -> [DatabaseObject] {
		
		// Can’t create a Set, because we can’t make a Set<DatabaseObject>, because protocol-conforming objects can’t be made Hashable or even Equatable.
		// We still want the array to include only one copy of each object, but we have to do it the slow way. Instruments will tell us if this is a performance problem.

		var relatedObjectsUniqueArray = [DatabaseObject]()
		for object in objects {
			guard let relatedObjects = object.relatedObjectsWithName(relationshipName) else {
				assertionFailure("uniqueArrayOfRelatedObjects: expected every object to have related objects.")
				continue
			}
			for relatedObject in relatedObjects {
				if !relatedObjectsUniqueArray.includesObjectWithDatabaseID(relatedObject.databaseID) {
					relatedObjectsUniqueArray += [relatedObject]
				}
			}
		}
		return relatedObjectsUniqueArray
	}
	
	func relatedObjectIDsMatchesCache(_ object: DatabaseObject) -> Bool {

		let relatedObjects = object.relatedObjectsWithName(relationshipName) ?? [DatabaseObject]()
		let cachedRelationshipIDs = cache[object.databaseID] ?? Set<String>()

		return relatedObjects.databaseIDs() == cachedRelationshipIDs
	}

	func syncRelatedObjectsAndLookupTable(_ object: DatabaseObject, _ lookupTable: LookupTable, _ database: FMDatabase) {
		
		guard let relatedObjects = object.relatedObjectsWithName(relationshipName) else {
			assertionFailure("syncRelatedObjectsAndLookupTable should be called only on objects with related objects.")
			return
		}
		
		let relatedObjectIDs = relatedObjects.databaseIDs()
		let lookupTableRelatedObjectIDs = lookupTable[object.databaseID] ?? Set<String>()
		
		let relatedObjectIDsToDelete = lookupTableRelatedObjectIDs.subtracting(relatedObjectIDs)
		if !relatedObjectIDsToDelete.isEmpty {
			deleteLookups(for: object.databaseID, relatedObjectIDsToDelete, database)
		}
		
		let relatedObjectIDsToSave = relatedObjectIDs.subtracting(lookupTableRelatedObjectIDs)
		if !relatedObjectIDsToSave.isEmpty {
			saveLookups(for: object.databaseID, relatedObjectIDsToSave, database)
		}
	}
	
	func saveLookups(for objectID: String, _ relatedObjectIDs: Set<String>, _ database: FMDatabase) {
		
		for relatedObjectID in relatedObjectIDs {
			let d: [NSObject: Any] = [(objectIDKey as NSString): objectID, (relatedObjectIDKey as NSString): relatedObjectID]
			let _ = database.rs_insertRow(with: d, insertType: .orIgnore, tableName: name)
		}
	}
	
	// MARK: Attaching
	
	func attachRelatedObjectsUsingCache(_ objects: [DatabaseObject], _ database: FMDatabase) {
		
		let lookupTable = cache.lookupTableForObjectIDs(objects.databaseIDs())
		attachRelatedObjectsUsingLookupTable(objects, lookupTable, database)
	}
	
	func fetchRelatedObjectsReferencedByLookupTable(_ lookupTable: LookupTable, _ database: FMDatabase) -> [DatabaseObject]? {
		
		let relatedObjectIDs = lookupTable.relatedObjectIDs()
		if (relatedObjectIDs.isEmpty) {
			return nil
		}
		
		return fetchRelatedObjectsWithIDs(relatedObjectIDs)
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
		
		let relatedObjects = relatedTable.fetchObjectsWithIDs(relatedObjectIDs, in: database)
		if relatedObjects.isEmpty {
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
	
	func relatedObjectsDictionary(_ lookupTable: LookupTable, relatedObjects: [DatabaseObject]) -> RelatedObjectsDictionary? {
		
		var relatedObjectsDictionary = RelatedObjectsDictionary()
		let d = relatedObjects.dictionary()
		
		
		
		
		return relatedObjectsDictionary.isEmpty ? nil : relatedObjectsDictionary
	}
}

// MARK: -

private struct LookupTable {
	
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

	func objectIDs() -> Set<String> {
		
		return Set(dictionary.keys)
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

private struct LookupValue: Hashable {

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
	
	func objectIDsThatMayHaveRelatedObjects(_ objectIDs: Set<String>) -> Set<String> {
		
		// Filter out objects that are known to have no related objects
		return Set(objectIDs.filter{ !objectIDsWithNoRelationship.contains($0) })
	}
	
//	func objectsThatMayHaveRelatedObjects(_ objects: [DatabaseObject]) -> [DatabaseObject] {
//
//		// Filter out objects that are known to have no related objects
//		return objects.filter{ !objectIDsWithNoRelationship.contains($0.databaseID) }
//	}
	
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

