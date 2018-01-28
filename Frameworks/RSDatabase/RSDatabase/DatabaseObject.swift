//
//  DatabaseObject.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DatabaseObject {

	var databaseID: String { get }

	func databaseDictionary() -> NSDictionary?

	func relatedObjectsWithName(_ name: String) -> [DatabaseObject]?
}

public extension DatabaseObject {
	
	func relatedObjectsWithName(_ name: String) -> [DatabaseObject]? {
		
		return nil
	}
}

extension Array where Element == DatabaseObject {

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

	func databaseDictionaries() -> [NSDictionary]? {

		let dictionaries = self.compactMap{ $0.databaseDictionary() }
		return dictionaries.isEmpty ? nil : dictionaries
	}
}
