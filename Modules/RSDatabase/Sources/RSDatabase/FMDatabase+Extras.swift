//
//  FMDatabase+Extras.swift
//
//
//  Created by Brent Simmons on 3/10/24.
//

import Foundation
import RSDatabaseObjC
import os

public extension FMDatabase {

	static func openAndSetUpDatabase(path: String) -> FMDatabase {
		let database = FMDatabase(path: path)!

		database.open()
		// All databases are single-connection and serialized — WAL gains us nothing
		// and produces extra -wal/-shm files that bloat on disk.
		database.executeStatements("PRAGMA journal_mode = DELETE;")
		database.executeStatements("PRAGMA synchronous = 1;")
		database.setShouldCacheStatements(true)

		return database
	}

	/// Returns false if the update failed and the transaction was rolled back.
	@discardableResult
	func executeUpdateInTransaction(_ sql: String, withArgumentsIn parameters: [Any]? = nil) -> Bool {
		beginTransaction()
		guard executeUpdate(sql, withArgumentsIn: parameters) else {
			// Capture the error before rollback() overwrites the last-error state.
			let code = lastErrorCode()
			let message = lastErrorMessage() ?? "unknown"
			let path = databasePath() ?? "unknown"
			rollback()
			Self.logger.error("Update failed on \(path, privacy: .public) — SQLite \(code, privacy: .public): \(message, privacy: .public)")
			return false
		}
		return commit()
	}

	private static let logger = Logger(subsystem: logSubsystem, category: "FMDatabase")

	func vacuum() {
		let path = databasePath() ?? "unknown"
		let start = Date()
		executeStatements("vacuum;")
		let duration = Date().timeIntervalSince(start)
		Self.logger.debug("VACUUM \(path, privacy: .public) took \(duration, format: .fixed(precision: 4), privacy: .public) seconds")
	}

	/// Vacuum if at least `daysBetweenVacuums` have passed since last time.
	/// The last vacuum date is stored in the database.
	func vacuumIfNeeded(daysBetweenVacuums: Int = RSDatabaseInfoTable.defaultDaysBetweenVacuums) {
		RSDatabaseInfoTable.createTableIfNeeded(database: self)

		if let lastVacuumDate = RSDatabaseInfoTable.lastVacuumDate(database: self) {
			let secondsBetweenVacuums = TimeInterval(daysBetweenVacuums) * 24 * 60 * 60
			if Date().timeIntervalSince(lastVacuumDate) < secondsBetweenVacuums {
				return
			}
		}

		vacuum()
		RSDatabaseInfoTable.setLastVacuumDate(Date(), database: self)
	}

	func runCreateStatements(_ statements: String) {
		statements.enumerateLines { (line, stop) in
			if line.lowercased().hasPrefix("create") {
				self.executeStatements(line)
			}
			stop = false
		}
	}

	/// Returns false if any row failed to insert. Every row is attempted either way.
	@discardableResult
	func insertRows(_ dictionaries: [DatabaseDictionary], insertType: RSDatabaseInsertType, tableName: String) -> Bool {
		var didInsertAllRows = true
		for dictionary in dictionaries {
			if !insertRow(dictionary, insertType: insertType, tableName: tableName) {
				didInsertAllRows = false
			}
		}
		return didInsertAllRows
	}

	@discardableResult
	func insertRow(_ dictionary: DatabaseDictionary, insertType: RSDatabaseInsertType, tableName: String) -> Bool {
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

	func deleteRowsWhere(key: String, equals value: Any, tableName: String) {
		rs_deleteRowsWhereKey(key, equalsValue: value, tableName: tableName)
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
