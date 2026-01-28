//
//  AccountFeedbinSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/6/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

@MainActor final class AccountFeedbinSyncTest: XCTestCase {
	
	func testDownloadSync() async throws {

		let testTransport = TestTransport()
		testTransport.testFiles["tags.json"] = "JSON/tags_add.json"
		testTransport.testFiles["subscriptions.json"] = "JSON/subscriptions_initial.json"
		let account = TestAccountManager.shared.createAccount(type: .feedbin, transport: testTransport)

		// Test initial folders
		try await account.refreshAll()

		XCTAssertEqual(224, account.flattenedFeeds().count)

		let daringFireball = account.idToFeedDictionary["1296379"]
		XCTAssertEqual("Daring Fireball", daringFireball!.name)
		XCTAssertEqual("https://daringfireball.net/feeds/json", daringFireball!.url)
		XCTAssertEqual("https://daringfireball.net/", daringFireball!.homePageURL)

		// Test Adding a Feed
		testTransport.testFiles["subscriptions.json"] = "JSON/subscriptions_add.json"

		try await account.refreshAll()

		XCTAssertEqual(225, account.flattenedFeeds().count)

		let bPixels = account.idToFeedDictionary["1096623"]
		XCTAssertEqual("Beautiful Pixels", bPixels?.name)
		XCTAssertEqual("https://feedpress.me/beautifulpixels", bPixels?.url)
		XCTAssertEqual("https://beautifulpixels.com/", bPixels?.homePageURL)

		TestAccountManager.shared.deleteAccount(account)
	}
}
