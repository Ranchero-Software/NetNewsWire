//
//  FeedSettingsDatabaseTests.swift
//  AccountTests
//
//  Created by Claude on 5/13/26.
//

import XCTest
import RSDatabaseObjC
@testable import Account

@MainActor final class FeedSettingsDatabaseTests: XCTestCase {

	private var tempDirectory: String!

	override func setUp() async throws {
		tempDirectory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
	}

	override func tearDown() async throws {
		if let tempDirectory {
			try? FileManager.default.removeItem(atPath: tempDirectory)
		}
		tempDirectory = nil
	}

	// MARK: - sortIndex

	func testSortIndexDefaultsToZero() {
		let database = FeedSettingsDatabase(databasePath: databasePath())
		database.ensureFeedExists("https://example.com/feed", feedID: "feed1")

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.sortIndex, 0)
	}

	func testSetSortIndexRoundTrips() {
		let database = FeedSettingsDatabase(databasePath: databasePath())
		database.ensureFeedExists("https://example.com/feed", feedID: "feed1")

		database.setInt(7, for: "https://example.com/feed", column: .sortIndex)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.sortIndex, 7)
	}

	func testSortIndexPersistsAcrossReopen() {
		let path = databasePath()

		do {
			let database = FeedSettingsDatabase(databasePath: path)
			database.ensureFeedExists("https://example.com/feed", feedID: "feed1")
			database.setInt(3, for: "https://example.com/feed", column: .sortIndex)
			_ = database.allRows() // force the serial queue to drain the writes
		}

		let reopened = FeedSettingsDatabase(databasePath: path)
		XCTAssertEqual(reopened.allRows()["https://example.com/feed"]?.sortIndex, 3)
	}

	/// A database created by a build that predates the `sortIndex` column must
	/// open cleanly, keep its rows, and gain the column with a default of 0.
	func testMigrationFromSchemaWithoutSortIndex() {
		let path = databasePath()

		let legacyDDL = "CREATE TABLE IF NOT EXISTS feedSettings (feedURL TEXT PRIMARY KEY, feedID TEXT NOT NULL DEFAULT '', homePageURL TEXT, iconURL TEXT, faviconURL TEXT, editedName TEXT, contentHash TEXT, newArticleNotificationsEnabled INTEGER NOT NULL DEFAULT 0, readerViewAlwaysEnabled INTEGER NOT NULL DEFAULT 0, authors TEXT, conditionalGetInfoLastModified TEXT, conditionalGetInfoEtag TEXT, conditionalGetInfoDate REAL, cacheControlInfoDateCreated REAL, cacheControlInfoMaxAge REAL, externalID TEXT, folderRelationship TEXT, lastCheckDate REAL);"

		let legacyDatabase = FMDatabase.openAndSetUpDatabase(path: path)
		legacyDatabase.executeStatements(legacyDDL)
		legacyDatabase.executeUpdate("INSERT INTO feedSettings (feedURL, feedID, editedName) VALUES (?, ?, ?);", withArgumentsIn: ["https://example.com/feed", "feed1", "Legacy Feed"])
		legacyDatabase.close()

		let database = FeedSettingsDatabase(databasePath: path)
		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.editedName, "Legacy Feed")
		XCTAssertEqual(row?.sortIndex, 0)

		database.setInt(11, for: "https://example.com/feed", column: .sortIndex)
		XCTAssertEqual(database.allRows()["https://example.com/feed"]?.sortIndex, 11)
	}

	// MARK: - Helpers

	private func databasePath() -> String {
		(tempDirectory as NSString).appendingPathComponent("FeedSettings.sqlite")
	}
}
