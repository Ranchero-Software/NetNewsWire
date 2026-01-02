//
//  DatabaseLookupTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/5/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization
import RSDatabaseObjC

// Implement a lookup table for a many-to-many relationship.
// Example: CREATE TABLE if not EXISTS authorLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));
// articleID is objectID; authorID is relatedObjectID.

public final class DatabaseLookupTable: Sendable {
	private let name: String
	private let objectIDKey: String
	private let relatedObjectIDKey: String
	private let relationshipName: String
	private let relatedTable: DatabaseRelatedObjectsTable

	// Performance optimization: cache objectIDs that have no related objects,
	// so we can avoid some fetches and other database work.
	//
	// The Mutex is not really needed, since this object always runs within
	// the context of a serial dispatch queue. But the Mutex proves
	// to the compiler that this is Sendable, and the cost of that is so small.
	// (The Mutex will never face contention.)
	private let objectIDsWithNoRelatedObjects = Mutex(Set<String>())

	public init(name: String, objectIDKey: String, relatedObjectIDKey: String, relatedTable: DatabaseRelatedObjectsTable, relationshipName: String) {
		self.name = name
		self.objectIDKey = objectIDKey
		self.relatedObjectIDKey = relatedObjectIDKey
		self.relatedTable = relatedTable
		self.relationshipName = relationshipName
	}

	public func fetchRelatedObjects(for objectIDs: Set<String>, in database: FMDatabase) -> RelatedObjectsMap? {
		let objectIDsThatMayHaveRelatedObjects = objectIDsSubtractingObjectIDsWithNoRelatedObjects(objectIDs)
		if objectIDsThatMayHaveRelatedObjects.isEmpty { // None of the objectIDs has a related object. Skip the fetch.
			return nil
		}

		guard let relatedObjectIDsMap = fetchRelatedObjectIDsMap(objectIDsThatMayHaveRelatedObjects, database) else {
			cacheObjectIDsWithNoRelatedObjects(objectIDsThatMayHaveRelatedObjects) // They don’t have related objects.
			return nil
		}

		if let relatedObjects = fetchRelatedObjectsWithIDs(relatedObjectIDsMap.relatedObjectIDs(), database) {

			let relatedObjectsMap = RelatedObjectsMap(relatedObjects: relatedObjects, relatedObjectIDsMap: relatedObjectIDsMap)

			let objectIDsWithNoFetchedRelatedObjects = objectIDsThatMayHaveRelatedObjects.subtracting(relatedObjectsMap.objectIDs())
			cacheObjectIDsWithNoRelatedObjects(objectIDsWithNoFetchedRelatedObjects)

			return relatedObjectsMap
		}

		return nil
	}

	public func saveRelatedObjects(for objects: [DatabaseObject], in database: FMDatabase) {

		var objectsWithNoRelationships = [DatabaseObject]()
		var objectsWithRelationships = [DatabaseObject]()

		for object in objects {
			if let relatedObjects = object.relatedObjectsWithName(relationshipName), !relatedObjects.isEmpty {
				objectsWithRelationships += [object]
			} else {
				objectsWithNoRelationships += [object]
			}
		}

		removeRelationships(for: objectsWithNoRelationships, database)
		updateRelationships(for: objectsWithRelationships, database)

		cacheObjectIDsWithNoRelatedObjects(objectsWithNoRelationships.databaseIDs())
		uncacheObjectIDsWithNoRelatedObjects(objectsWithRelationships.databaseIDs())
	}
}

// MARK: - Private

private extension DatabaseLookupTable {

	// MARK: Removing

	func removeRelationships(for objects: [DatabaseObject], _ database: FMDatabase) {
		let objectIDs = objects.databaseIDs()
		let objectIDsToRemove = objectIDsSubtractingObjectIDsWithNoRelatedObjects(objectIDs)
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
		_ = database.executeUpdate(sql, withArgumentsIn: parameters)
	}

	// MARK: Saving/Updating

	func updateRelationships(for objects: [DatabaseObject], _ database: FMDatabase) {

		if objects.isEmpty {
			return
		}

		if let lookupTable = fetchRelatedObjectIDsMap(objects.databaseIDs(), database) {
			for object in objects {
				syncRelatedObjectsAndLookupTable(object, lookupTable, database)
			}
		}

		// Save the actual related objects.

		let relatedObjectsToSave = uniqueArrayOfRelatedObjects(with: objects)
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

	func syncRelatedObjectsAndLookupTable(_ object: DatabaseObject, _ lookupTable: RelatedObjectIDsMap, _ database: FMDatabase) {

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
			_ = database.rs_insertRow(with: d, insertType: .orIgnore, tableName: name)
		}
	}

	// MARK: Fetching

	func fetchRelatedObjectsWithIDs(_ relatedObjectIDs: Set<String>, _ database: FMDatabase) -> [DatabaseObject]? {

		guard let relatedObjects = relatedTable.fetchObjectsWithIDs(relatedObjectIDs, in: database), !relatedObjects.isEmpty else {
			return nil
		}
		return relatedObjects
	}

	func fetchRelatedObjectIDsMap(_ objectIDs: Set<String>, _ database: FMDatabase) -> RelatedObjectIDsMap? {

		guard let lookupValues = fetchLookupValues(objectIDs, database) else {
			return nil
		}
		return RelatedObjectIDsMap(lookupValues: lookupValues)
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

	// MARK: - Object IDs with no related objects

	func objectIDsSubtractingObjectIDsWithNoRelatedObjects(_ objectIDs: Set<String>) -> Set<String> {
		objectIDsWithNoRelatedObjects.withLock { objectIDs.subtracting($0) }
	}

	func cacheObjectIDsWithNoRelatedObjects(_ objectIDs: Set<String>) {
		objectIDsWithNoRelatedObjects.withLock { $0.formUnion(objectIDs) }
	}

	func uncacheObjectIDsWithNoRelatedObjects(_ objectIDs: Set<String>) {
		objectIDsWithNoRelatedObjects.withLock { $0.subtract(objectIDs) }
	}
}

