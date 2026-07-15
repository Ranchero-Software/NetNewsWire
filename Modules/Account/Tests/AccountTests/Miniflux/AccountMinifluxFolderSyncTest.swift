//
//  AccountMinifluxFolderSyncTest.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
@testable import Account

@MainActor final class AccountMinifluxFolderSyncTest: XCTestCase {

	override func setUp() {
		TestingURLProtocol.reset()
	}

	func testDownloadSync() async throws {

		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		account.endpointURL = URL(string: "https://miniflux.test")

		// Test initial folders

		try await account.refreshAll()

		guard let initialFolders = account.folders else {
			XCTFail()
			return
		}

		XCTAssertEqual(3, initialFolders.count)

		guard let all = initialFolders.first(where: { $0.name == "All" }) else {
			XCTFail("Expected an “All” folder")
			return
		}
		XCTAssertEqual("1", all.externalID)

		guard let tech = initialFolders.first(where: { $0.name == "Tech" }) else {
			XCTFail("Expected a “Tech” folder")
			return
		}
		XCTAssertEqual("2", tech.externalID)

		guard let news = initialFolders.first(where: { $0.name == "News" }) else {
			XCTFail("Expected a “News” folder")
			return
		}
		XCTAssertEqual("3", news.externalID)

		// Test removing a folder

		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_delete.json")

		try await account.refreshAll()

		guard let deleteFolders = account.folders else {
			XCTFail()
			return
		}

		XCTAssertEqual(2, deleteFolders.count)
		let deleteFolderNames = deleteFolders.map { $0.name ?? "" }
		XCTAssertTrue(deleteFolderNames.contains("All"))
		XCTAssertTrue(deleteFolderNames.contains("Tech"))
		XCTAssertFalse(deleteFolderNames.contains("News"))

		// Test adding a folder

		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_add.json")

		try await account.refreshAll()

		guard let addFolders = account.folders else {
			XCTFail()
			return
		}

		XCTAssertEqual(4, addFolders.count)
		let addFolderNames = addFolders.map { $0.name ?? "" }
		XCTAssertTrue(addFolderNames.contains("News"))
		XCTAssertTrue(addFolderNames.contains("Reviews"))

		guard let reviews = addFolders.first(where: { $0.name == "Reviews" }) else {
			XCTFail("Expected a “Reviews” folder")
			return
		}
		XCTAssertEqual("4", reviews.externalID)

		TestAccountManager.shared.deleteAccount(account)
	}

	func testFeedsLandInCorrectFolders() async throws {

		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		guard let folders = account.folders else {
			XCTFail()
			return
		}
		XCTAssertEqual(3, folders.count)

		guard let all = folders.first(where: { $0.name == "All" }) else {
			XCTFail("Expected an “All” folder")
			return
		}
		guard let tech = folders.first(where: { $0.name == "Tech" }) else {
			XCTFail("Expected a “Tech” folder")
			return
		}
		guard let news = folders.first(where: { $0.name == "News" }) else {
			XCTFail("Expected a “News” folder")
			return
		}

		// Feeds 101 and 105 belong to category 1 (“All”).
		XCTAssertEqual(2, all.topLevelFeeds.count)
		let allFeedExternalIDs = Set(all.topLevelFeeds.map { $0.externalID })
		XCTAssertEqual(Set(["101", "105"]), allFeedExternalIDs)

		// Feeds 102 and 103 belong to category 2 (“Tech”).
		XCTAssertEqual(2, tech.topLevelFeeds.count)
		let techFeedExternalIDs = Set(tech.topLevelFeeds.map { $0.externalID })
		XCTAssertEqual(Set(["102", "103"]), techFeedExternalIDs)

		// Feed 104 belongs to category 3 (“News”).
		XCTAssertEqual(1, news.topLevelFeeds.count)
		let newsFeedExternalIDs = Set(news.topLevelFeeds.map { $0.externalID })
		XCTAssertEqual(Set(["104"]), newsFeedExternalIDs)

		// Miniflux feeds always belong to exactly one category, so nothing should land
		// at the account's top level.
		XCTAssertEqual(0, account.topLevelFeeds.count)

		guard let generalFeed = all.topLevelFeeds.first(where: { $0.externalID == "101" }) else {
			XCTFail("Expected feed 101 in the “All” folder")
			return
		}
		XCTAssertEqual("https://miniflux.test/feeds/general.xml", generalFeed.url)
		XCTAssertEqual("General Feed", generalFeed.name)

		TestAccountManager.shared.deleteAccount(account)
	}

}
