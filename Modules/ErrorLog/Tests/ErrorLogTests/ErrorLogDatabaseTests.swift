//
//  ErrorLogDatabaseTests.swift
//  ErrorLog
//
//  Created by Brent Simmons on 3/12/26.
//

import Testing
import Foundation
@testable import ErrorLog

@Suite(.serialized) struct ErrorLogDatabaseTests {

	private func temporaryDatabasePath() -> String {
		let tempDir = NSTemporaryDirectory()
		let filename = "ErrorLogTests-\(UUID().uuidString).db"
		return (tempDir as NSString).appendingPathComponent(filename)
	}

	private func deleteDatabaseFiles(at path: String) {
		for suffix in ["", "-wal", "-shm"] {
			try? FileManager.default.removeItem(atPath: path + suffix)
		}
	}

	@Test func addAndRetrieveEntry() async {
		let path = temporaryDatabasePath()
		defer { deleteDatabaseFiles(at: path) }

		let database = ErrorLogDatabase(databasePath: path)
		await database.addEntry(sourceName: "TestAccount", sourceID: 1, errorMessage: "Something went wrong")

		let entries = await database.allEntries()
		#expect(entries.count == 1)

		let entry = entries[0]
		#expect(entry.sourceName == "TestAccount")
		#expect(entry.sourceID == 1)
		#expect(entry.errorMessage == "Something went wrong")
		#expect(entry.id > 0)
	}

	@Test func entriesReturnedInInsertionOrder() async {
		let path = temporaryDatabasePath()
		defer { deleteDatabaseFiles(at: path) }

		let database = ErrorLogDatabase(databasePath: path)
		await database.addEntry(sourceName: "First", sourceID: 1, errorMessage: "Error 1")
		await database.addEntry(sourceName: "Second", sourceID: 2, errorMessage: "Error 2")
		await database.addEntry(sourceName: "Third", sourceID: 3, errorMessage: "Error 3")

		let entries = await database.allEntries()
		#expect(entries.count == 3)
		#expect(entries[0].sourceName == "First")
		#expect(entries[1].sourceName == "Second")
		#expect(entries[2].sourceName == "Third")
		#expect(entries[0].id < entries[1].id)
		#expect(entries[1].id < entries[2].id)
	}

	@Test func pruneOnInit() async {
		let path = temporaryDatabasePath()
		defer { deleteDatabaseFiles(at: path) }

		let database = ErrorLogDatabase(databasePath: path)
		for i in 1...210 {
			await database.addEntry(sourceName: "Account", sourceID: 1, errorMessage: "Error \(i)")
		}

		let entriesBeforePrune = await database.allEntries()
		#expect(entriesBeforePrune.count == 210)

		// Creating a new database at the same path triggers pruning on init.
		let database2 = ErrorLogDatabase(databasePath: path)
		let entriesAfterPrune = await database2.allEntries()
		#expect(entriesAfterPrune.count == 200)

		// Oldest entries should have been removed; newest should remain.
		#expect(entriesAfterPrune[0].errorMessage == "Error 11")
		#expect(entriesAfterPrune[199].errorMessage == "Error 210")
	}
}
