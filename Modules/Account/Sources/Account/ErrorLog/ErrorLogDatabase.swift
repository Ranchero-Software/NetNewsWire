//
//  ErrorLogDatabase.swift
//  Account
//
//  Created by Brent Simmons on 3/11/26.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

public actor ErrorLogDatabase {

	private let database: FMDatabase

	private static let tableCreationStatements = "CREATE TABLE if not EXISTS errors (id INTEGER PRIMARY KEY AUTOINCREMENT, date REAL NOT NULL, accountName TEXT NOT NULL, accountType INTEGER NOT NULL, errorMessage TEXT NOT NULL);"

	private static let pruneLimit = 200

	public init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.executeStatements("PRAGMA journal_mode = WAL;")
		database.runCreateStatements(Self.tableCreationStatements)
		ErrorLogTable.pruneEntries(limit: Self.pruneLimit, database: database)

		self.database = database
	}
	
	public func addEntry(accountName: String, accountType: Int, errorMessage: String) {
		ErrorLogTable.insertEntry(accountName: accountName, accountType: accountType, errorMessage: errorMessage, database: database)
	}

	public func allEntries() -> [ErrorLogEntry] {
		ErrorLogTable.allEntries(database: database)
	}

	public func deleteAll() {
		ErrorLogTable.deleteAll(database: database)
	}
}
