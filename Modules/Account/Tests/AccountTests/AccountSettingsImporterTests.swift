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
	private let accountID = "testAccount123"

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

	// MARK: - Tests

	func testNoPlistFile() {
		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNil(result)
	}

	func testUnreadablePlistFile() {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("Settings.plist")
		try! FileManager.default.createDirectory(atPath: plistPath, withIntermediateDirectories: true)

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNil(result)
	}

	func testCorruptedPlistFile() {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("Settings.plist")
		try! "not a plist at all".data(using: .utf8)!.write(to: URL(fileURLWithPath: plistPath))

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNil(result)
	}

	func testEmptyPlist() {
		writePlist([:])

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNotNil(result)
		XCTAssertNil(result?.name)
		XCTAssertNil(result?.isActive)
		XCTAssertNil(result?.username)
		XCTAssertNil(result?.lastArticleFetchStartTime)
		XCTAssertNil(result?.lastRefreshCompletedDate)
		XCTAssertNil(result?.endpointURL)
		XCTAssertNil(result?.externalID)
		XCTAssertNil(result?.conditionalGetInfo)
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

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNotNil(result)
		XCTAssertEqual(result?.name, "My Account")
		XCTAssertEqual(result?.isActive, false)
		XCTAssertEqual(result?.username, "testuser")
		XCTAssertEqual(result?.lastArticleFetchStartTime?.timeIntervalSinceReferenceDate ?? .nan, fetchDate.timeIntervalSinceReferenceDate, accuracy: 0.001)
		XCTAssertEqual(result?.lastRefreshCompletedDate?.timeIntervalSinceReferenceDate ?? .nan, fetchEndDate.timeIntervalSinceReferenceDate, accuracy: 0.001)
		XCTAssertEqual(result?.endpointURL, URL(string: "https://example.com/api"))
		XCTAssertEqual(result?.externalID, "ext-42")
	}

	func testConditionalGetInfo() {
		writePlist([
			"conditionalGetInfo": [
				"https://example.com/feed1": ["lastModified": "Wed, 01 Jan 2025 00:00:00 GMT", "etag": "abc123"],
				"https://example.com/feed2": ["etag": "def456"]
			]
		])

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNotNil(result)

		let info1 = result?.conditionalGetInfo?["https://example.com/feed1"]
		XCTAssertNotNil(info1)
		XCTAssertEqual(info1?.lastModified, "Wed, 01 Jan 2025 00:00:00 GMT")
		XCTAssertEqual(info1?.etag, "abc123")

		let info2 = result?.conditionalGetInfo?["https://example.com/feed2"]
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

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNotNil(result)
		// Both lastModified and etag are nil, so HTTPConditionalGetInfo init returns nil
		XCTAssertNil(result?.conditionalGetInfo?["https://example.com/feed"])
	}

	func testSubsetOfFields() {
		writePlist([
			"name": "Partial Account",
			"username": "partialuser"
		])

		let result = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: tempDirectory)
		XCTAssertNotNil(result)
		XCTAssertEqual(result?.name, "Partial Account")
		XCTAssertEqual(result?.username, "partialuser")
		XCTAssertNil(result?.isActive)
		XCTAssertNil(result?.lastArticleFetchStartTime)
		XCTAssertNil(result?.lastRefreshCompletedDate)
		XCTAssertNil(result?.endpointURL)
		XCTAssertNil(result?.externalID)
	}

	// MARK: - Helpers

	private func writePlist(_ dictionary: [String: Any]) {
		let plistPath = (tempDirectory as NSString).appendingPathComponent("Settings.plist")
		let data = try! PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
		try! data.write(to: URL(fileURLWithPath: plistPath))
	}
}
