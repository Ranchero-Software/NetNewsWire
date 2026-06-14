//
//  AccountFeedbinFolderContentsSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/7/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
@testable import Account

@MainActor final class AccountFeedbinFolderContentsSyncTest: XCTestCase {

	override func setUp() {
		TestingURLProtocol.reset()
	}

	func testDownloadSync() async throws {
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/tags.json", file: "JSON/tags_add.json")
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/subscriptions.json", file: "JSON/subscriptions_initial.json")
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/taggings.json", file: "JSON/taggings_initial.json")
		let account = TestAccountManager.shared.createAccount(type: .feedbin)

		// Test initial folders
		try await account.refreshAll()

		let folder = account.folders?.filter { $0.name == "Developers" } .first!
		XCTAssertEqual(156, folder?.topLevelFeeds.count ?? 0)
		XCTAssertEqual(2, account.topLevelFeeds.count)

		// Test Adding a Feed to the folder
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/taggings.json", file: "JSON/taggings_add.json")

		try await account.refreshAll()

		XCTAssertEqual(157, folder?.topLevelFeeds.count ?? 0)
		XCTAssertEqual(1, account.topLevelFeeds.count)

		// Test Deleting some Feeds from the folder
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/taggings.json", file: "JSON/taggings_delete.json")

		try await account.refreshAll()

		XCTAssertEqual(153, folder?.topLevelFeeds.count ?? 0)
		XCTAssertEqual(5, account.topLevelFeeds.count)

		TestAccountManager.shared.deleteAccount(account)
	}
}
