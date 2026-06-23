//
//  RSDatabaseInfoTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 5/27/26.
//

import Foundation
import RSDatabaseObjC

/// Shared single-table key/value store kept in every database, under a common
/// name, for RSDatabase-level bookkeeping. Currently it records the last
/// vacuum date (see `FMDatabase.vacuumIfNeeded`); it can hold more per-database
/// metadata later (schema version, last-prune date, etc.).
public enum RSDatabaseInfoTable {

	public static let tableName = "RSDatabaseInfo"
	public static let defaultDaysBetweenVacuums = 13

	private static let keyColumn = "key"
	private static let valueColumn = "value"
	private static let lastVacuumDateKey = "lastVacuumDate"

	static func createTableIfNeeded(database: FMDatabase) {
		database.executeStatements("CREATE TABLE IF NOT EXISTS \(tableName) (\(keyColumn) TEXT PRIMARY KEY NOT NULL, \(valueColumn));")
	}

	static func lastVacuumDate(database: FMDatabase) -> Date? {
		guard let resultSet = database.executeQuery("SELECT \(valueColumn) FROM \(tableName) WHERE \(keyColumn) = ?;", withArgumentsIn: [lastVacuumDateKey]) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}
		return Date(timeIntervalSince1970: resultSet.double(forColumn: valueColumn))
	}

	static func setLastVacuumDate(_ date: Date, database: FMDatabase) {
		database.executeUpdate("INSERT OR REPLACE INTO \(tableName) (\(keyColumn), \(valueColumn)) VALUES (?, ?);", withArgumentsIn: [lastVacuumDateKey, date.timeIntervalSince1970])
	}
}
