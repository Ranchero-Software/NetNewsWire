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
import os

public actor ErrorLogDatabase {

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ErrorLogDatabase")

	private let database: FMDatabase

	private static let tableCreationStatements = "CREATE TABLE if not EXISTS errors (id INTEGER PRIMARY KEY AUTOINCREMENT, date REAL NOT NULL, sourceName TEXT NOT NULL, sourceID INTEGER NOT NULL, operation TEXT NOT NULL DEFAULT '', fileName TEXT NOT NULL DEFAULT '', functionName TEXT NOT NULL DEFAULT '', lineNumber INTEGER NOT NULL DEFAULT 0, errorMessage TEXT NOT NULL);"

	private static let pruneLimit = 200

	public init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.executeStatements("PRAGMA journal_mode = WAL;")
		database.runCreateStatements(Self.tableCreationStatements)
		ErrorLogTable.pruneEntries(limit: Self.pruneLimit, database: database)
		Self.vacuum(database: database)

		self.database = database

		if !Platform.isRunningUnitTests {
			NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEncounterError(_:)), name: .appDidEncounterError, object: nil)
		}
	}

	public func addEntry(sourceName: String, sourceID: Int, operation: String, fileName: String, functionName: String, lineNumber: Int, errorMessage: String) {
		ErrorLogTable.insertEntry(sourceName: sourceName, sourceID: sourceID, operation: operation, fileName: fileName, functionName: functionName, lineNumber: lineNumber, errorMessage: errorMessage, database: database)
	}

	public func allEntries() -> [ErrorLogEntry] {
		ErrorLogTable.allEntries(database: database)
	}

	// MARK: - Maintenance

	private static func vacuum(database: FMDatabase) {
		let start = CFAbsoluteTimeGetCurrent()
		database.executeStatements("VACUUM;")
		let duration = CFAbsoluteTimeGetCurrent() - start
		logger.debug("ErrorLogDatabase: VACUUM took \(duration, format: .fixed(precision: 4)) seconds")
	}

	// MARK: - Notifications

	@objc nonisolated func handleAppDidEncounterError(_ notification: Notification) {
		guard let errorMessage = notification.userInfo?[ErrorLogUserInfoKey.errorMessage] as? String,
			  let sourceName = notification.userInfo?[ErrorLogUserInfoKey.sourceName] as? String,
			  let sourceID = notification.userInfo?[ErrorLogUserInfoKey.sourceID] as? Int else {
			return
		}
		
		let operation = notification.userInfo?[ErrorLogUserInfoKey.operation] as? String ?? ""
		let fileName = notification.userInfo?[ErrorLogUserInfoKey.fileName] as? String ?? ""
		let functionName = notification.userInfo?[ErrorLogUserInfoKey.functionName] as? String ?? ""
		let lineNumber = notification.userInfo?[ErrorLogUserInfoKey.lineNumber] as? Int ?? 0

		Task {
			await addEntry(sourceName: sourceName, sourceID: sourceID, operation: operation, fileName: fileName, functionName: functionName, lineNumber: lineNumber, errorMessage: errorMessage)
		}
	}
}
