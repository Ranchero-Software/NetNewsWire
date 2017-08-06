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

public struct LookupTable {

	let name: String
	let primaryKey: String
	let foreignKey: String

	public init(name: String, primaryKey: String, foreignKey: String) {

		self.name = name
		self.primaryKey = primaryKey
		self.foreignKey = foreignKey
	}

	public func fetchLookupValues(_ foreignIDs: Set<String>, database: FMDatabase) -> Set<LookupValue> {

		guard let resultSet = database.rs_selectRowsWhereKey(foreignKey, inValues: Array(foreignIDs), tableName: name) else {
			return Set<LookupValue>()
		}
		return lookupValuesWithResultSet(resultSet)
	}
}

private extension LookupTable {

	func lookupValuesWithResultSet(_ resultSet: FMResultSet) -> Set<LookupValue> {

		return resultSet.mapToSet(lookupValueWithRow)
	}

	func lookupValueWithRow(_ resultSet: FMResultSet) -> LookupValue? {

		guard let primaryID = resultSet.string(forColumn: primaryKey) else {
			return nil
		}
		guard let foreignID = resultSet.string(forColumn: foreignKey) else {
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
