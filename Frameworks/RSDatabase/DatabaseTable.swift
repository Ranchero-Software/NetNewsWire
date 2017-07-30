//
//  DatabaseTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DatabaseTable {
	
	var name: String {get}
	var queue: RSDatabaseQueue {get}
	
	init(name: String, queue: RSDatabaseQueue)
}

public extension DatabaseTable {

	// MARK: Fetching

	public func selectRowsWhere(key: String, equals value: Any, in database: FMDatabase) -> FMResultSet? {
		
		return database.rs_selectRowsWhereKey(key, equalsValue: value, tableName: name)
	}

	public func selectRowsWhere(key: String, inValues values: [Any], in database: FMDatabase) -> FMResultSet? {

		return database.rs_selectRowsWhereKey(key, inValues: values, tableName: name)
	}

	// MARK: Deleting

	public func deleteRowsWhere(key: String, equalsAnyValue values: [Any], in database: FMDatabase) {
		
		if values.isEmpty {
			return
		}
		
		database.rs_deleteRowsWhereKey(key, inValues: values, tableName: name)
	}

	// MARK: Updating

	public func updateRowsWithValue(_ value: Any, valueKey: String, whereKey: String, matches: [Any]) {

		queue.update { (database: FMDatabase!) in

			let _ = database.rs_updateRows(withValue: value, valueKey: valueKey, whereKey: whereKey, inValues: matches, tableName: self.name)
		}
	}

	// MARK: Saving

	public func insertRows(_ dictionaries: [NSDictionary], insertType: RSDatabaseInsertType) {

		queue.update { (database: FMDatabase!) -> Void in

			dictionaries.forEach { (oneDictionary) in
				let _ = database.rs_insertRow(with: oneDictionary as [NSObject: AnyObject], insertType: insertType, tableName: self.name)
			}
		}
	}

	// MARK: Counting

	func numberWithCountResultSet(_ resultSet: FMResultSet?) -> Int {

		if let resultSet = resultSet, resultSet.next() {
			return Int(resultSet.int(forColumnIndex: 0))
		}
		return 0
	}

	func numberWithSQLAndParameters(_ sql: String, _ parameters: [Any], in database: FMDatabase) -> Int {

		let resultSet = database.executeQuery(sql, withArgumentsIn: parameters)
		return numberWithCountResultSet(resultSet)
	}
}

