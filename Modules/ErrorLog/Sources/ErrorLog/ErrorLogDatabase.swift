//
//  ErrorLogDatabase.swift
//  ErrorLog
//
//  Created by Brent Simmons on 3/11/26.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC

public actor ErrorLogDatabase {

	private let database: FMDatabase

	private static let tableCreationStatements = "CREATE TABLE if not EXISTS errors (id INTEGER PRIMARY KEY AUTOINCREMENT, date REAL NOT NULL, sourceName TEXT NOT NULL, sourceID INTEGER NOT NULL, errorMessage TEXT NOT NULL);"

	private static let pruneLimit = 200

	public init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.executeStatements("PRAGMA journal_mode = WAL;")
		database.runCreateStatements(Self.tableCreationStatements)
		ErrorLogTable.pruneEntries(limit: Self.pruneLimit, database: database)

		self.database = database

		if !Platform.isRunningUnitTests {
			NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEncounterError(_:)), name: .appDidEncounterError, object: nil)
		}
	}

	public func addEntry(sourceName: String, sourceID: Int, errorMessage: String) {
		ErrorLogTable.insertEntry(sourceName: sourceName, sourceID: sourceID, errorMessage: errorMessage, database: database)
	}

	public func allEntries() -> [ErrorLogEntry] {
		ErrorLogTable.allEntries(database: database)
	}

	// MARK: - Notifications

	@objc nonisolated func handleAppDidEncounterError(_ notification: Notification) {
		guard let errorMessage = notification.userInfo?[ErrorLogUserInfoKey.errorMessage] as? String,
			  let sourceName = notification.userInfo?[ErrorLogUserInfoKey.sourceName] as? String,
			  let sourceID = notification.userInfo?[ErrorLogUserInfoKey.sourceID] as? Int else {
			return
		}
		Task {
			await addEntry(sourceName: sourceName, sourceID: sourceID, errorMessage: errorMessage)
		}
	}
}
