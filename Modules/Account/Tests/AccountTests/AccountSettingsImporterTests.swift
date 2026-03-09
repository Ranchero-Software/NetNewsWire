//
//  AccountSettingsImporterTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 3/8/26.
//

import XCTest
import RSWeb
@testable import Account

@MainActor final class AccountSettingsImporterTests: XCTestCase {

	private var tempDirectory: String!
	private var database: AccountSettingsDatabase!
	private let accountID = "testAccount123"

	override func setUp() async throws {
		tempDirectory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
		let dbPath = (tempDirectory as NSString).appendingPathComponent("Settings.sqlite")
		database = AccountSettingsDatabase(databasePath: dbPath)
	}

	override func tearDown() async throws {
		database = nil
		if let tempDirectory {
			try? FileManager.default.removeItem(atPath: tempDirectory)
		}
		tempDirectory = nil
	}

	// MARK: - Tests

	func testNoPlistFile() {
		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)
		XCTAssertFalse(database.accountExists(accountID))
	}

	func testAccountAlreadyExists() {
		writePlist(["name": "Test"])
		database.ensureAccountExists(accountID)

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)

		let row = database.row(for: accountID)
		XCTAssertNil(row?.name)
	}

	func testUnreadablePlistFile() {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("Settings.plist")
		try! FileManager.default.createDirectory(atPath: plistPath, withIntermediateDirectories: true)

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)
		XCTAssertFalse(database.accountExists(accountID))
	}

	func testCorruptedPlistFile() {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("Settings.plist")
		try! "not a plist at all".data(using: .utf8)!.write(to: URL(fileURLWithPath: plistPath))

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)
		XCTAssertFalse(database.accountExists(accountID))
	}

	func testEmptyPlist() {
		writePlist([:])

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)

		XCTAssertTrue(database.accountExists(accountID))
		let row = database.row(for: accountID)
		XCTAssertNotNil(row)
		XCTAssertNil(row?.name)
		XCTAssertTrue(row?.isActive ?? false)
		XCTAssertNil(row?.username)
		XCTAssertNil(row?.lastArticleFetchStartTime)
		XCTAssertNil(row?.lastRefreshCompletedDate)
		XCTAssertNil(row?.endpointURL)
		XCTAssertNil(row?.externalID)
	}

	func testAllFields() {
		let fetchDate = Date(timeIntervalSinceReferenceDate: 700000000)
		let fetchEndDate = Date(timeIntervalSinceReferenceDate: 700000060)

		writePlist([
			"name": "My Account",
			"isActive": false,
			"username": "testuser",
			"lastArticleFetch": fetchDate,
			"lastArticleFetchEndTime": fetchEndDate,
			"endpointURL": "https://example.com/api",
			"externalID": "ext-42"
		])

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)

		let row = database.row(for: accountID)
		XCTAssertNotNil(row)
		XCTAssertEqual(row?.name, "My Account")
		XCTAssertEqual(row?.isActive, false)
		XCTAssertEqual(row?.username, "testuser")
		XCTAssertEqual(row?.lastArticleFetchStartTime?.timeIntervalSinceReferenceDate ?? .nan, fetchDate.timeIntervalSinceReferenceDate, accuracy: 0.001)
		XCTAssertEqual(row?.lastRefreshCompletedDate?.timeIntervalSinceReferenceDate ?? .nan, fetchEndDate.timeIntervalSinceReferenceDate, accuracy: 0.001)
		XCTAssertEqual(row?.endpointURL, URL(string: "https://example.com/api"))
		XCTAssertEqual(row?.externalID, "ext-42")
	}

	func testConditionalGetInfo() {
		writePlist([
			"conditionalGetInfo": [
				"https://example.com/feed1": ["lastModified": "Wed, 01 Jan 2025 00:00:00 GMT", "etag": "abc123"],
				"https://example.com/feed2": ["etag": "def456"]
			]
		])

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)

		let info1 = database.conditionalGetInfo(for: accountID, endpoint: "https://example.com/feed1")
		XCTAssertNotNil(info1)
		XCTAssertEqual(info1?.lastModified, "Wed, 01 Jan 2025 00:00:00 GMT")
		XCTAssertEqual(info1?.etag, "abc123")

		let info2 = database.conditionalGetInfo(for: accountID, endpoint: "https://example.com/feed2")
		XCTAssertNotNil(info2)
		XCTAssertNil(info2?.lastModified)
		XCTAssertEqual(info2?.etag, "def456")
	}

	func testConditionalGetInfoBothNil() {
		writePlist([
			"conditionalGetInfo": [
				"https://example.com/feed": [String: String]()
			]
		])

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)

		XCTAssertTrue(database.accountExists(accountID))
		let info = database.conditionalGetInfo(for: accountID, endpoint: "https://example.com/feed")
		XCTAssertNil(info)
	}

	func testSubsetOfFields() {
		writePlist([
			"name": "Partial Account",
			"username": "partialuser"
		])

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)

		let row = database.row(for: accountID)
		XCTAssertNotNil(row)
		XCTAssertEqual(row?.name, "Partial Account")
		XCTAssertEqual(row?.username, "partialuser")
		XCTAssertTrue(row?.isActive ?? false)
		XCTAssertNil(row?.lastArticleFetchStartTime)
		XCTAssertNil(row?.lastRefreshCompletedDate)
		XCTAssertNil(row?.endpointURL)
		XCTAssertNil(row?.externalID)
	}

	func testImportIsOneTime() {
		writePlist(["name": "Original Name"])

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)
		XCTAssertEqual(database.row(for: accountID)?.name, "Original Name")

		// Overwrite plist with different data
		writePlist(["name": "Changed Name"])

		// Second import should be a no-op since account already exists in DB
		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: tempDirectory, database: database)
		XCTAssertEqual(database.row(for: accountID)?.name, "Original Name")
	}

	// MARK: - Helpers

	private func writePlist(_ dictionary: [String: Any]) {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("Settings.plist")
		let data = try! PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
		try! data.write(to: URL(fileURLWithPath: plistPath))
	}
}
