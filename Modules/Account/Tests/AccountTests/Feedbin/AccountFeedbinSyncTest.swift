//
//  AccountFeedbinSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/6/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//class AccountFeedbinSyncTest: XCTestCase {
//
//    override func setUp() {
//    }
//
//    override func tearDown() {
//    }
//
//	func testDownloadSync() {
//		
//		let testTransport = TestTransport()
//		testTransport.testFiles["tags.json"] = "JSON/tags_add.json"
//		testTransport.testFiles["subscriptions.json"] = "JSON/subscriptions_initial.json"
//		let account = TestAccountManager.shared.createAccount(type: .feedbin, transport: testTransport)
//		
//		// Test initial folders
//		let initialExpection = self.expectation(description: "Initial feeds")
//		account.refreshAll() { result in
//			switch result {
//			case .success:
//				initialExpection.fulfill()
//			case .failure(let error):
//				XCTFail(error.localizedDescription)
//			}
//		}
//		waitForExpectations(timeout: 5, handler: nil)
//		
//		XCTAssertEqual(224, account.flattenedFeeds().count)
//
//		let daringFireball = account.idToFeedDictionary["1296379"]
//		XCTAssertEqual("Daring Fireball", daringFireball!.name)
//		XCTAssertEqual("https://daringfireball.net/feeds/json", daringFireball!.url)
//		XCTAssertEqual("https://daringfireball.net/", daringFireball!.homePageURL)
//
//		// Test Adding a Feed
//		testTransport.testFiles["subscriptions.json"] = "JSON/subscriptions_add.json"
//		
//		let addExpection = self.expectation(description: "Add feeds")
//		account.refreshAll() { result in
//			switch result {
//			case .success:
//				addExpection.fulfill()
//			case .failure(let error):
//				XCTFail(error.localizedDescription)
//			}
//		}
//		waitForExpectations(timeout: 5, handler: nil)
//		
//		XCTAssertEqual(225, account.flattenedFeeds().count)
//		
//		let bPixels = account.idToFeedDictionary["1096623"]
//		XCTAssertEqual("Beautiful Pixels", bPixels?.name)
//		XCTAssertEqual("https://feedpress.me/beautifulpixels", bPixels?.url)
//		XCTAssertEqual("https://beautifulpixels.com/", bPixels?.homePageURL)
//
//		TestAccountManager.shared.deleteAccount(account)
//
//	}
//	
//}
