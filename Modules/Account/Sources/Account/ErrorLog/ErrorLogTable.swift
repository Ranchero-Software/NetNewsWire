//
//  ErrorLogTable.swift
//  Account
//
//  Created by Brent Simmons on 3/11/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

struct ErrorLogTable {

	static let name = "errors"

	static func insertEntry(accountName: String, accountType: Int, errorMessage: String, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			ErrorLogEntry.DatabaseKey.date: Date().timeIntervalSince1970,
			ErrorLogEntry.DatabaseKey.accountName: accountName,
			ErrorLogEntry.DatabaseKey.accountType: accountType,
			ErrorLogEntry.DatabaseKey.errorMessage: errorMessage
		]
		database.insertRow(dictionary, insertType: .normal, tableName: name)
	}

	static func allEntries(database: FMDatabase) -> [ErrorLogEntry] {
		let sql = "select * from \(name) order by id asc"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return []
		}

		var entries = [ErrorLogEntry]()
		while resultSet.next() {
			if let entry = entryWithRow(resultSet) {
				entries.append(entry)
			}
		}
		return entries
	}

	static func pruneEntries(limit: Int, database: FMDatabase) {
		let sql = "delete from \(name) where id not in (select id from \(name) order by id desc limit \(limit))"
		database.executeUpdateInTransaction(sql)
	}

	static func deleteAll(database: FMDatabase) {
		let sql = "delete from \(name)"
		database.executeUpdateInTransaction(sql)
	}
}

private extension ErrorLogTable {

	static func entryWithRow(_ row: FMResultSet) -> ErrorLogEntry? {
		guard let accountName = row.string(forColumn: ErrorLogEntry.DatabaseKey.accountName),
			  let errorMessage = row.string(forColumn: ErrorLogEntry.DatabaseKey.errorMessage) else {
			return nil
		}

		let id = row.longLongInt(forColumn: ErrorLogEntry.DatabaseKey.id)
		let date = Date(timeIntervalSince1970: row.double(forColumn: ErrorLogEntry.DatabaseKey.date))
		let accountType = Int(row.int(forColumn: ErrorLogEntry.DatabaseKey.accountType))

		return ErrorLogEntry(id: id, date: date, accountName: accountName, accountType: accountType, errorMessage: errorMessage)
	}
}
