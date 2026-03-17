//
//  FeedSettingsImporterTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 3/8/26.
//

import XCTest
import RSWeb
import Articles
@testable import Account

@MainActor final class FeedSettingsImporterTests: XCTestCase {

	private var tempDirectory: String!
	private var database: FeedSettingsDatabase!

	override func setUp() async throws {
		tempDirectory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
		let dbPath = (tempDirectory as NSString).appendingPathComponent("FeedSettings.sqlite")
		database = FeedSettingsDatabase(databasePath: dbPath)
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
		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertTrue(database.isEmpty)
	}

	func testDatabaseAlreadyHasRows() {
		writePlist([
			"https://example.com/feed": ["feedID": "feed1"]
		])

		// Pre-populate the database so isEmpty returns false
		database.ensureFeedExists("https://other.com/feed", feedID: "other")

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		// The plist feed should NOT have been imported
		let rows = database.allRows()
		XCTAssertNil(rows["https://example.com/feed"])
		XCTAssertNotNil(rows["https://other.com/feed"])
	}

	func testUnreadablePlistFile() {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("FeedMetadata.plist")
		try! FileManager.default.createDirectory(atPath: plistPath, withIntermediateDirectories: true)

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertTrue(database.isEmpty)
	}

	func testCorruptedPlistFile() {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("FeedMetadata.plist")
		try! "not a valid plist".data(using: .utf8)!.write(to: URL(fileURLWithPath: plistPath))

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertTrue(database.isEmpty)
	}

	func testEmptyPlist() {
		writePlist([:])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertTrue(database.isEmpty)
	}

	func testNonDictionaryFeedValueSkipped() {
		writePlist([
			"https://example.com/feed": "not a dictionary"
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertTrue(database.isEmpty)
	}

	func testMinimalFeed() {
		writePlist([
			"https://example.com/feed": [String: Any]()
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let rows = database.allRows()
		let row = rows["https://example.com/feed"]
		XCTAssertNotNil(row)
		// feedID defaults to feedURL when not present in dict
		XCTAssertEqual(row?.feedID, "https://example.com/feed")
		XCTAssertNil(row?.homePageURL)
		XCTAssertNil(row?.editedName)
		XCTAssertEqual(row?.newArticleNotificationsEnabled, false)
		XCTAssertEqual(row?.readerViewAlwaysEnabled, false)
		XCTAssertNil(row?.conditionalGetInfo)
		XCTAssertNil(row?.conditionalGetInfoDate)
		XCTAssertNil(row?.cacheControlInfo)
		XCTAssertNil(row?.authors)
		XCTAssertNil(row?.externalID)
		XCTAssertNil(row?.folderRelationship)
		XCTAssertNil(row?.lastCheckDate)
	}

	func testAllStringFields() {
		writePlist([
			"https://example.com/feed": [
				"feedID": "custom-feed-id",
				"homePageURL": "https://example.com",
				"iconURL": "https://example.com/icon.png",
				"faviconURL": "https://example.com/favicon.ico",
				"editedName": "My Custom Name",
				"contentHash": "abc123hash",
				"subscriptionID": "ext-sub-99"
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNotNil(row)
		XCTAssertEqual(row?.feedID, "custom-feed-id")
		XCTAssertEqual(row?.homePageURL, "https://example.com")
		XCTAssertEqual(row?.iconURL, "https://example.com/icon.png")
		XCTAssertEqual(row?.faviconURL, "https://example.com/favicon.ico")
		XCTAssertEqual(row?.editedName, "My Custom Name")
		XCTAssertEqual(row?.contentHash, "abc123hash")
		XCTAssertEqual(row?.externalID, "ext-sub-99")
	}

	func testBoolFields() {
		writePlist([
			"https://example.com/feed": [
				"isNotifyAboutNewArticles": true,
				"isArticleExtractorAlwaysOn": true
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNotNil(row)
		XCTAssertTrue(row?.newArticleNotificationsEnabled ?? false)
		XCTAssertTrue(row?.readerViewAlwaysEnabled ?? false)
	}

	func testConditionalGetInfo() {
		writePlist([
			"https://example.com/feed": [
				"conditionalGetInfo": [
					"lastModified": "Wed, 01 Jan 2025 00:00:00 GMT",
					"etag": "abc123"
				]
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNotNil(row?.conditionalGetInfo)
		XCTAssertEqual(row?.conditionalGetInfo?.lastModified, "Wed, 01 Jan 2025 00:00:00 GMT")
		XCTAssertEqual(row?.conditionalGetInfo?.etag, "abc123")
	}

	func testConditionalGetInfoDate() {
		let date = Date(timeIntervalSinceReferenceDate: 700000000)

		writePlist([
			"https://example.com/feed": [
				"conditionalGetInfoDate": date
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.conditionalGetInfoDate?.timeIntervalSinceReferenceDate ?? .nan, date.timeIntervalSinceReferenceDate, accuracy: 0.001)
	}

	func testCacheControlInfo() {
		let dateCreated = Date(timeIntervalSinceReferenceDate: 700000000)
		let maxAge: Double = 3600

		writePlist([
			"https://example.com/feed": [
				"cacheControlInfo": [
					"dateCreated": dateCreated,
					"maxAge": maxAge
				] as [String: Any]
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNotNil(row?.cacheControlInfo)
		XCTAssertEqual(row?.cacheControlInfo?.dateCreated.timeIntervalSinceReferenceDate ?? .nan, dateCreated.timeIntervalSinceReferenceDate, accuracy: 0.001)
		XCTAssertEqual(row?.cacheControlInfo?.maxAge ?? .nan, maxAge, accuracy: 0.001)
	}

	func testCacheControlInfoPartialSkipped() {
		// Only dateCreated, no maxAge — should not import
		let dateCreated = Date(timeIntervalSinceReferenceDate: 700000000)
		writePlist([
			"https://example.com/feed": [
				"cacheControlInfo": [
					"dateCreated": dateCreated
				] as [String: Any]
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNil(row?.cacheControlInfo)
	}

	func testAuthors() {
		let authorDict: [String: Any] = [
			"name": "Brent Simmons",
			"url": "https://inessential.com/",
			"authorID": "author1"
		]

		writePlist([
			"https://example.com/feed": [
				"authors": [authorDict]
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNotNil(row?.authors)
		XCTAssertEqual(row?.authors?.count, 1)
		XCTAssertEqual(row?.authors?.first?.name, "Brent Simmons")
		XCTAssertEqual(row?.authors?.first?.url, "https://inessential.com/")
	}

	func testFolderRelationship() {
		writePlist([
			"https://example.com/feed": [
				"folderRelationship": [
					"Tech": "folder-id-1",
					"News": "folder-id-2"
				]
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertNotNil(row?.folderRelationship)
		XCTAssertEqual(row?.folderRelationship?["Tech"], "folder-id-1")
		XCTAssertEqual(row?.folderRelationship?["News"], "folder-id-2")
	}

	func testLastCheckDate() {
		let date = Date(timeIntervalSinceReferenceDate: 700000000)

		writePlist([
			"https://example.com/feed": [
				"lastCheckDate": date
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.lastCheckDate?.timeIntervalSinceReferenceDate ?? .nan, date.timeIntervalSinceReferenceDate, accuracy: 0.001)
	}

	func testMultipleFeeds() {
		writePlist([
			"https://example.com/feed1": [
				"feedID": "id1",
				"editedName": "Feed One"
			] as [String: Any],
			"https://example.com/feed2": [
				"feedID": "id2",
				"editedName": "Feed Two"
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let rows = database.allRows()
		XCTAssertEqual(rows.count, 2)
		XCTAssertEqual(rows["https://example.com/feed1"]?.editedName, "Feed One")
		XCTAssertEqual(rows["https://example.com/feed2"]?.editedName, "Feed Two")
	}

	func testImportIsOneTime() {
		writePlist([
			"https://example.com/feed": [
				"editedName": "Original"
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertEqual(database.allRows()["https://example.com/feed"]?.editedName, "Original")

		// Overwrite plist
		writePlist([
			"https://example.com/feed": [
				"editedName": "Changed"
			] as [String: Any]
		])

		// Second import should be a no-op
		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)
		XCTAssertEqual(database.allRows()["https://example.com/feed"]?.editedName, "Original")
	}

	func testFeedIDDefaultsToFeedURL() {
		writePlist([
			"https://example.com/feed": [
				"editedName": "No Feed ID"
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.feedID, "https://example.com/feed")
	}

	func testFeedIDFromDict() {
		writePlist([
			"https://example.com/feed": [
				"feedID": "custom-id"
			] as [String: Any]
		])

		FeedSettingsImporter.importIfNeeded(dataFolder: tempDirectory, database: database)

		let row = database.allRows()["https://example.com/feed"]
		XCTAssertEqual(row?.feedID, "custom-id")
	}

	// MARK: - Helpers

	private func writePlist(_ dictionary: [String: Any]) {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("FeedMetadata.plist")
		let data = try! PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
		try! data.write(to: URL(fileURLWithPath: plistPath))
	}
}
