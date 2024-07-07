//
//  File.swift
//  
//
//  Created by Brent Simmons on 3/10/24.
//

import Foundation
import FMDB

public extension FMDatabase {

	static func openAndSetUpDatabase(path: String) -> FMDatabase {

		let database = FMDatabase(path: path)!

		database.open()
		database.executeStatements("PRAGMA synchronous = 1;")
		database.setShouldCacheStatements(true)

		return database
	}

	func executeUpdateInTransaction(_ sql : String, withArgumentsIn parameters: [Any]? = nil) {

		beginTransaction()
		executeUpdate(sql, withArgumentsIn: parameters)
		commit()
	}

	func vacuum() {

		executeStatements("vacuum;")
	}

	func runCreateStatements(_ statements: String) {

		statements.enumerateLines { (line, stop) in
			if line.lowercased().hasPrefix("create") {
				self.executeStatements(line)
			}
			stop = false
		}
	}

	func insertRows(_ dictionaries: [DatabaseDictionary], insertType: RSDatabaseInsertType, tableName: String) {

		for dictionary in dictionaries {
			insertRow(dictionary, insertType: insertType, tableName: tableName)
		}
	}

	func insertRow(_ dictionary: DatabaseDictionary, insertType: RSDatabaseInsertType, tableName: String) {

		rs_insertRow(with: dictionary, insertType: insertType, tableName: tableName)
	}

	func updateRowsWithValue(_ value: Any, valueKey: String, whereKey: String, equalsAnyValue values: [Any], tableName: String) {

		rs_updateRows(withValue: value, valueKey: valueKey, whereKey: whereKey, inValues: values, tableName: tableName)
	}

	func updateRowsWithValue(_ value: Any, valueKey: String, whereKey: String, equals match: Any, tableName: String) {

		updateRowsWithValue(value, valueKey: valueKey, whereKey: whereKey, equalsAnyValue: [match], tableName: tableName)
	}

	func updateRowsWithDictionary(_ dictionary: [String: Any], whereKey: String, equals value: Any, tableName: String) {

		rs_updateRows(with: dictionary, whereKey: whereKey, equalsValue: value, tableName: tableName)
	}

	func deleteRowsWhere(key: String, equalsAnyValue values: [Any], tableName: String) {

		rs_deleteRowsWhereKey(key, inValues: values, tableName: tableName)
	}

	func selectRowsWhere(key: String, equalsAnyValue values: [Any], tableName: String) -> FMResultSet? {
		
		rs_selectRowsWhereKey(key, inValues: values, tableName: tableName)
	}

	func count(sql: String, parameters: [Any]?, tableName: String) -> Int? {

		guard let resultSet = executeQuery(sql, withArgumentsIn: parameters) else {
			return nil
		}
		
		let count = resultSet.intWithCountResult()
		return count
	}
}
