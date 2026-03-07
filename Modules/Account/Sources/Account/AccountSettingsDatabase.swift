//
//  AccountSettingsDatabase.swift
//  Account
//
//  Created by Brent Simmons on 3/6/26.
//

import Foundation
import os
import RSDatabase
import RSDatabaseObjC
import RSWeb

@MainActor final class AccountSettingsDatabase {
	enum Column: String {
		case name
		case isActive
		case username
		case lastArticleFetchStartTime
		case lastArticleFetchEndTime
		case endpointURL
		case externalID
	}

	struct Row {
		var name: String?
		var isActive: Bool
		var username: String?
		var lastArticleFetchStartTime: Date?
		var lastArticleFetchEndTime: Date?
		var endpointURL: URL?
		var externalID: String?
	}

	private let database: FMDatabase

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountSettingsDatabase")

	init(databasePath: String) {
		self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.executeStatements("PRAGMA journal_mode = WAL;")
		database.runCreateStatements(Self.tableCreationStatements)
		database.vacuumIfNeeded(daysBetweenVacuums: 30, filepath: databasePath)
	}

	// MARK: - Account Existence

	func accountExists(_ accountID: String) -> Bool {
		guard let resultSet = database.executeQuery("SELECT 1 FROM accountSettings WHERE accountID = ?;", withArgumentsIn: [accountID]) else {
			return false
		}
		let exists = resultSet.next()
		resultSet.close()
		return exists
	}

	func ensureAccountExists(_ accountID: String) {
		database.executeUpdate("INSERT OR IGNORE INTO accountSettings (accountID) VALUES (?);", withArgumentsIn: [accountID])
	}

	func deleteSettings(for accountID: String) {
		database.executeUpdate("DELETE FROM accountSettings WHERE accountID = ?;", withArgumentsIn: [accountID])
		database.executeUpdate("DELETE FROM conditionalGetInfo WHERE accountID = ?;", withArgumentsIn: [accountID])
	}

	// MARK: - Fetch Row

	func row(for accountID: String) -> Row? {
		guard let resultSet = database.executeQuery("SELECT * FROM accountSettings WHERE accountID = ?;", withArgumentsIn: [accountID]) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}

		var row = Row(name: nil, isActive: true, username: nil)
		row.name = resultSet.string(forColumn: Column.name.rawValue)
		row.isActive = resultSet.bool(forColumn: Column.isActive.rawValue)
		row.username = resultSet.string(forColumn: Column.username.rawValue)
		row.externalID = resultSet.string(forColumn: Column.externalID.rawValue)

		if !resultSet.columnIsNull(Column.lastArticleFetchStartTime.rawValue) {
			row.lastArticleFetchStartTime = Date(timeIntervalSinceReferenceDate: resultSet.double(forColumn: Column.lastArticleFetchStartTime.rawValue))
		}
		if !resultSet.columnIsNull(Column.lastArticleFetchEndTime.rawValue) {
			row.lastArticleFetchEndTime = Date(timeIntervalSinceReferenceDate: resultSet.double(forColumn: Column.lastArticleFetchEndTime.rawValue))
		}
		if let endpointURLString = resultSet.string(forColumn: Column.endpointURL.rawValue) {
			row.endpointURL = URL(string: endpointURLString)
		}

		return row
	}

	// MARK: - String

	func string(for accountID: String, column: Column) -> String? {
		let name = column.rawValue
		guard let resultSet = database.executeQuery("SELECT \(name) FROM accountSettings WHERE accountID = ?;", withArgumentsIn: [accountID]) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}
		return resultSet.string(forColumn: name)
	}

	func setString(_ value: String?, for accountID: String, column: Column) {
		let name = column.rawValue
		if let value {
			database.executeUpdate("UPDATE accountSettings SET \(name) = ? WHERE accountID = ?;", withArgumentsIn: [value, accountID])
		} else {
			database.executeUpdate("UPDATE accountSettings SET \(name) = NULL WHERE accountID = ?;", withArgumentsIn: [accountID])
		}
	}

	// MARK: - Bool

	func bool(for accountID: String, column: Column) -> Bool {
		let name = column.rawValue
		guard let resultSet = database.executeQuery("SELECT \(name) FROM accountSettings WHERE accountID = ?;", withArgumentsIn: [accountID]) else {
			return false
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return false
		}
		return resultSet.bool(forColumn: name)
	}

	func setBool(_ value: Bool, for accountID: String, column: Column) {
		database.executeUpdate("UPDATE accountSettings SET \(column.rawValue) = ? WHERE accountID = ?;", withArgumentsIn: [value, accountID])
	}

	// MARK: - Date

	func date(for accountID: String, column: Column) -> Date? {
		let name = column.rawValue
		guard let resultSet = database.executeQuery("SELECT \(name) FROM accountSettings WHERE accountID = ?;", withArgumentsIn: [accountID]) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}
		if resultSet.columnIsNull(name) {
			return nil
		}
		return Date(timeIntervalSinceReferenceDate: resultSet.double(forColumn: name))
	}

	func setDate(_ value: Date?, for accountID: String, column: Column) {
		let name = column.rawValue
		if let value {
			database.executeUpdate("UPDATE accountSettings SET \(name) = ? WHERE accountID = ?;", withArgumentsIn: [value.timeIntervalSinceReferenceDate, accountID])
		} else {
			database.executeUpdate("UPDATE accountSettings SET \(name) = NULL WHERE accountID = ?;", withArgumentsIn: [accountID])
		}
	}

	// MARK: - Conditional Get Info

	func conditionalGetInfo(for accountID: String, endpoint: String) -> HTTPConditionalGetInfo? {
		guard let resultSet = database.executeQuery("SELECT lastModified, etag FROM conditionalGetInfo WHERE accountID = ? AND endpoint = ?;", withArgumentsIn: [accountID, endpoint]) else {
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}
		let lastModified = resultSet.string(forColumn: "lastModified")
		let etag = resultSet.string(forColumn: "etag")
		return HTTPConditionalGetInfo(lastModified: lastModified, etag: etag)
	}

	func setConditionalGetInfo(_ info: HTTPConditionalGetInfo?, for accountID: String, endpoint: String) {
		if let info {
			Self.logger.debug("setConditionalGetInfo: setting for accountID \(accountID) endpoint \(endpoint)")
			database.executeUpdate("INSERT OR REPLACE INTO conditionalGetInfo (accountID, endpoint, lastModified, etag) VALUES (?, ?, ?, ?);", withArgumentsIn: [accountID, endpoint, info.lastModified as Any, info.etag as Any])
		} else {
			Self.logger.debug("setConditionalGetInfo: removing for accountID \(accountID) endpoint \(endpoint)")
			database.executeUpdate("DELETE FROM conditionalGetInfo WHERE accountID = ? AND endpoint = ?;", withArgumentsIn: [accountID, endpoint])
		}
	}
}

// MARK: - Private

private extension AccountSettingsDatabase {

	static let tableCreationStatements = """
	CREATE TABLE IF NOT EXISTS accountSettings (accountID TEXT PRIMARY KEY, name TEXT, isActive INTEGER DEFAULT 1, username TEXT, lastArticleFetchStartTime REAL, lastArticleFetchEndTime REAL, endpointURL TEXT, externalID TEXT);
	CREATE TABLE IF NOT EXISTS conditionalGetInfo (accountID TEXT NOT NULL, endpoint TEXT NOT NULL, lastModified TEXT, etag TEXT, PRIMARY KEY (accountID, endpoint));
	"""
}
