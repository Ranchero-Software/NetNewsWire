//
//  DatabaseObjectCache.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/29/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Not thread-safe.

public final class DatabaseObjectCache {

	private var dictionary = [String: DatabaseObject]()

	public init() {
		// Compiler seems to want a public init method.
	}
	
	public func addObjects(_ objects: [DatabaseObject]) {

		objects.forEach { add($0) }
	}

	public func addObjectsNotCached(_ objects: [DatabaseObject]) {

		objects.forEach { addIfNotCached($0) }
	}

	public func add(_ object: DatabaseObject) {

		self[object.databaseID] = object
	}

	public func addIfNotCached(_ object: DatabaseObject) {

		let identifier = object.databaseID
		if let _ = self[identifier] {
			return
		}
		self[identifier] = object
	}

	public func removeObjects(_ objects: [DatabaseObject]) {

		objects.forEach { removeObject($0) }
	}

	public func removeObject(_ object: DatabaseObject) {

		self[object.databaseID] = nil
	}

	public func uniquedObjects(_ objects: [DatabaseObject]) -> [DatabaseObject] {

		// Return cached version of each object.
		// When an object is not already cached, cache it,
		// then consider that version the unique version.

		return objects.map { (object) -> DatabaseObject in

			if let cachedObject = self[object.databaseID] {
				return cachedObject
			}
			add(object)
			return object
		}
	}

	public func objectWithIDIsCached(_ identifier: String) -> Bool {

		return self[identifier] != nil
	}

	public subscript(_ identifier: String) -> DatabaseObject? {
		get {
			return dictionary[identifier]
		}
		set {
			dictionary[identifier] = newValue
		}
	}
}

