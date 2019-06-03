//
//  AccountFolderContentsSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/7/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class AccountFolderContentsSyncTest: XCTestCase {

    override func setUp() {
    }

    override func tearDown() {
    }

	func testDownloadSync() {
		
		let testTransport = TestTransport()
		testTransport.testFiles["https://api.feedbin.com/v2/tags.json"] = "tags_add.json"
		testTransport.testFiles["https://api.feedbin.com/v2/subscriptions.json"] = "subscriptions_initial.json"
		testTransport.testFiles["https://api.feedbin.com/v2/taggings.json"] = "taggings_initial.json"
		testTransport.testFiles["https://api.feedbin.com/v2/icons.json"] = "icons.json"
		let account = TestAccountManager.shared.createAccount(type: .feedbin, transport: testTransport)
		
		// Test initial folders
		let initialExpection = self.expectation(description: "Initial contents")
		account.refreshAll() {
			initialExpection.fulfill()
		}
		waitForExpectations(timeout: 5, handler: nil)
		
		let folder = account.folders?.filter { $0.name == "Developers" } .first!
		XCTAssertEqual(156, folder?.topLevelFeeds.count ?? 0)
		XCTAssertEqual(2, account.topLevelFeeds.count)
		
		// Test Adding a Feed to the folder
		testTransport.testFiles["https://api.feedbin.com/v2/taggings.json"] = "taggings_add.json"

		let addExpection = self.expectation(description: "Add contents")
		account.refreshAll() {
			addExpection.fulfill()
		}
		waitForExpectations(timeout: 5, handler: nil)
		
		XCTAssertEqual(157, folder?.topLevelFeeds.count ?? 0)
		XCTAssertEqual(1, account.topLevelFeeds.count)

		// Test Deleting some Feeds from the folder
		testTransport.testFiles["https://api.feedbin.com/v2/taggings.json"] = "taggings_delete.json"
		
		let deleteExpection = self.expectation(description: "Delete contents")
		account.refreshAll() {
			deleteExpection.fulfill()
		}
		waitForExpectations(timeout: 5, handler: nil)
		
		XCTAssertEqual(153, folder?.topLevelFeeds.count ?? 0)
		XCTAssertEqual(5, account.topLevelFeeds.count)

		TestAccountManager.shared.deleteAccount(account)
		
	}
	
}
