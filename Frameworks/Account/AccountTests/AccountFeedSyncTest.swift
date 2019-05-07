//
//  AccountFullSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/6/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class AccountFeedSyncTest: XCTestCase {

    override func setUp() {
    }

    override func tearDown() {
    }

	func testDownloadSync() {
		
		let testTransport = TestTransport()
		testTransport.testFiles["https://api.feedbin.com/v2/tags.json"] = "tags_add.json"
		testTransport.testFiles["https://api.feedbin.com/v2/subscriptions.json"] = "subscriptions_initial.json"
		testTransport.testFiles["https://api.feedbin.com/v2/icons.json"] = "icons.json"
		let account = TestAccountManager.shared.createAccount(type: .feedbin, transport: testTransport)
		
		// Test initial folders
		let initialExpection = self.expectation(description: "Initial feeds")
		account.refreshAll() {
			initialExpection.fulfill()
		}
		waitForExpectations(timeout: 5, handler: nil)
		
		XCTAssertEqual(224, account.flattenedFeeds().count)

		let daringFireball = account.idToFeedDictionary["1296379"]
		XCTAssertEqual("Daring Fireball", daringFireball!.name)
		XCTAssertEqual("https://daringfireball.net/feeds/json", daringFireball!.url)
		XCTAssertEqual("https://daringfireball.net/", daringFireball!.homePageURL)
		XCTAssertEqual("https://favicons.feedbinusercontent.com/6ac/6acc098f35ed2bcc0915ca89d50a97e5793eda45.png", daringFireball!.faviconURL)

		// Test Adding a Feed
		testTransport.testFiles["https://api.feedbin.com/v2/subscriptions.json"] = "subscriptions_add.json"
		
		let addExpection = self.expectation(description: "Add feeds")
		account.refreshAll() {
			addExpection.fulfill()
		}
		waitForExpectations(timeout: 5, handler: nil)
		
		XCTAssertEqual(225, account.flattenedFeeds().count)
		
		let bPixels = account.idToFeedDictionary["1096623"]
		XCTAssertEqual("Beautiful Pixels", bPixels!.name)
		XCTAssertEqual("https://feedpress.me/beautifulpixels", bPixels!.url)
		XCTAssertEqual("https://beautifulpixels.com/", bPixels!.homePageURL)
		XCTAssertEqual("https://favicons.feedbinusercontent.com/ea0/ea010c658d6e356e49ab239b793dc415af707b05.png", bPixels?.faviconURL)

		TestAccountManager.shared.deleteAccount(account)

	}
	
}
