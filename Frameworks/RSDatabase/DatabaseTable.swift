//
//  DatabaseTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DatabaseTable {

	var name: String { get }
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

	public func updateRowsWithValue(_ value: Any, valueKey: String, whereKey: String, matches: [Any], database: FMDatabase) {
		
		let _ = database.rs_updateRows(withValue: value, valueKey: valueKey, whereKey: whereKey, inValues: matches, tableName: self.name)
	}
	
	public func updateRowsWithDictionary(_ dictionary: NSDictionary, whereKey: String, matches: Any, database: FMDatabase) {
		
		let _ = database.rs_updateRows(with: dictionary as! [AnyHashable : Any], whereKey: whereKey, equalsValue: matches, tableName: self.name)
	}
	
	// MARK: Saving

	public func insertRows(_ dictionaries: [NSDictionary], insertType: RSDatabaseInsertType, in database: FMDatabase) {

		dictionaries.forEach { (oneDictionary) in
			let _ = database.rs_insertRow(with: oneDictionary as [NSObject: AnyObject], insertType: insertType, tableName: self.name)
		}
	}

	// MARK: Counting

	func numberWithCountResultSet(_ resultSet: FMResultSet) -> Int {

		guard resultSet.next() else {
			return 0
		}
		return Int(resultSet.int(forColumnIndex: 0))
	}

	func numberWithSQLAndParameters(_ sql: String, _ parameters: [Any], in database: FMDatabase) -> Int {

		if let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) {
			return numberWithCountResultSet(resultSet)
		}
		return 0
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

	public func compactMap<T>(_ callback: (_ row: FMResultSet) -> T?) -> [T] {

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

		return Set(compactMap(callback))
	}
}

