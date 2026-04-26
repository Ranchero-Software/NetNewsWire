//
//  ErrorLogTable.swift
//  ErrorLog
//
//  Created by Brent Simmons on 3/11/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

struct ErrorLogTable {

	static let name = "errors"

	static func insertEntry(sourceName: String, sourceID: Int, operation: String, fileName: String, functionName: String, lineNumber: Int, errorMessage: String, database: FMDatabase) {
		let dictionary: DatabaseDictionary = [
			ErrorLogEntry.DatabaseKey.date: Date().timeIntervalSince1970,
			ErrorLogEntry.DatabaseKey.sourceName: sourceName,
			ErrorLogEntry.DatabaseKey.sourceID: sourceID,
			ErrorLogEntry.DatabaseKey.operation: operation,
			ErrorLogEntry.DatabaseKey.fileName: fileName,
			ErrorLogEntry.DatabaseKey.functionName: functionName,
			ErrorLogEntry.DatabaseKey.lineNumber: lineNumber,
			ErrorLogEntry.DatabaseKey.errorMessage: errorMessage
		]
		database.insertRow(dictionary, insertType: .normal, tableName: name)
	}

	static func allEntries(database: FMDatabase) -> [ErrorLogEntry] {
		let sql = "select * from \(name) order by id asc"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return []
		}
		return resultSet.compactMap(entryWithRow)
	}

	static func pruneEntries(limit: Int, database: FMDatabase) {
		let sql = "delete from \(name) where id not in (select id from \(name) order by id desc limit \(limit))"
		database.executeUpdateInTransaction(sql)
	}
}

private extension ErrorLogTable {

	static func entryWithRow(_ row: FMResultSet) -> ErrorLogEntry? {
		guard let sourceName = row.swiftString(forColumn: ErrorLogEntry.DatabaseKey.sourceName),
			  let errorMessage = row.swiftString(forColumn: ErrorLogEntry.DatabaseKey.errorMessage) else {
			return nil
		}

		let id = Int(row.longLongInt(forColumn: ErrorLogEntry.DatabaseKey.id))
		let date = Date(timeIntervalSince1970: row.double(forColumn: ErrorLogEntry.DatabaseKey.date))
		let sourceID = Int(row.int(forColumn: ErrorLogEntry.DatabaseKey.sourceID))
		let operation = row.swiftString(forColumn: ErrorLogEntry.DatabaseKey.operation) ?? ""
		let fileName = row.swiftString(forColumn: ErrorLogEntry.DatabaseKey.fileName) ?? ""
		let functionName = row.swiftString(forColumn: ErrorLogEntry.DatabaseKey.functionName) ?? ""
		let lineNumber = Int(row.int(forColumn: ErrorLogEntry.DatabaseKey.lineNumber))

		return ErrorLogEntry(id: id, date: date, sourceName: sourceName, sourceID: sourceID, operation: operation, fileName: fileName, functionName: functionName, lineNumber: lineNumber, errorMessage: errorMessage)
	}
}
