//
//  DatabaseObject.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias DatabaseDictionary = [String: Any]

nonisolated public protocol DatabaseObject: Sendable {

	var databaseID: String { get }

	func databaseDictionary() -> DatabaseDictionary?

	func relatedObjectsWithName(_ name: String) -> [DatabaseObject]?
}

nonisolated public extension DatabaseObject {

	func relatedObjectsWithName(_ name: String) -> [DatabaseObject]? {

		return nil
	}
}

nonisolated extension Array where Element == DatabaseObject {

	func dictionary() -> [String: DatabaseObject] {

		var d = [String: DatabaseObject]()
		for object in self {
			d[object.databaseID] = object
		}
		return d
	}

	func databaseIDs() -> Set<String> {

		return Set(self.map { $0.databaseID })
	}

	func includesObjectWithDatabaseID(_ databaseID: String) -> Bool {

		for object in self {
			if object.databaseID == databaseID {
				return true
			}
		}
		return false
	}

	func databaseDictionaries() -> [DatabaseDictionary]? {

		let dictionaries = self.compactMap{ $0.databaseDictionary() }
		return dictionaries.isEmpty ? nil : dictionaries
	}
}
