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
	
	func fetchObjectsWithIDs<T>(_ databaseIDs: Set<String>, _ database: FMDatabase) -> [T]
}

public extension DatabaseTable {

	// MARK: Fetching

	public func selectRowsWhere(key: String, equals value: Any, in database: FMDatabase) -> FMResultSet? {
		
		return database.rs_selectRowsWhereKey(key, equalsValue: value, tableName: name)
	}

	public func selectRowsWhere(key: String, inValues values: [Any], in database: FMDatabase) -> FMResultSet? {

		if values.isEmpty {
			return nil
		}
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

	public func insertRows(_ dictionaries: [NSDictionary], insertType: RSDatabaseInsertType, in database: FMDatabase) {

		dictionaries.forEach { (oneDictionary) in
			let _ = database.rs_insertRow(with: oneDictionary as [NSObject: AnyObject], insertType: insertType, tableName: self.name)
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

	// MARK: Mapping

	func mapResultSet<T>(_ resultSet: FMResultSet, _ callback: (_ resultSet: FMResultSet) -> T?) -> [T] {

		var objects = [T]()
		while resultSet.next() {
			if let obj = callback(resultSet) {
				objects += [obj]
			}
		}
		return objects
	}
}

public extension FMResultSet {

	public func flatMap<T>(_ callback: (_ row: FMResultSet) -> T?) -> [T] {

		var objects = [T]()
		while next() {
			if let obj = callback(self) {
				objects += [obj]
			}
		}
		close()
		return objects
	}

	public func mapToSet<T>(_ callback: (_ row: FMResultSet) -> T?) -> Set<T> {

		return Set(flatMap(callback))
	}
}

