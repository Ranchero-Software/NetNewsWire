//
//  AccountFeedbinFolderSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//class AccountFeedbinFolderSyncTest: XCTestCase {
//
//    override func setUp() {
//    }
//
//    override func tearDown() {
//    }
//
//    func testDownloadSync() {
//
//		let testTransport = TestTransport()
//		testTransport.testFiles["https://api.feedbin.com/v2/tags.json"] = "JSON/tags_initial.json"
//		let account = TestAccountManager.shared.createAccount(type: .feedbin, transport: testTransport)
//		
//		// Test initial folders
//		let initialExpection = self.expectation(description: "Initial tags")
//		account.refreshAll() { _ in
//			initialExpection.fulfill()
//		}
//		waitForExpectations(timeout: 5, handler: nil)
//		
//		guard let intialFolders = account.folders else {
//			XCTFail()
//			return
//		}
//		
//		XCTAssertEqual(9, intialFolders.count)
//		let initialFolderNames = intialFolders.map { $0.name ?? "" }
//		XCTAssertTrue(initialFolderNames.contains("Outdoors"))
//
//		// Test removing folders
//		testTransport.testFiles["https://api.feedbin.com/v2/tags.json"] = "JSON/tags_delete.json"
//		
//		let deleteExpection = self.expectation(description: "Delete tags")
//		account.refreshAll() { _ in
//			deleteExpection.fulfill()
//		}
//		waitForExpectations(timeout: 5, handler: nil)
//		
//		guard let deleteFolders = account.folders else {
//			XCTFail()
//			return
//		}
//		
//		XCTAssertEqual(8, deleteFolders.count)
//		let deleteFolderNames = deleteFolders.map { $0.name ?? "" }
//		XCTAssertTrue(deleteFolderNames.contains("Outdoors"))
//		XCTAssertFalse(deleteFolderNames.contains("Tech Media"))
//
//		// Test Adding Folders
//		testTransport.testFiles["https://api.feedbin.com/v2/tags.json"] = "JSON/tags_add.json"
//		
//		let addExpection = self.expectation(description: "Add tags")
//		account.refreshAll() { _ in 
//			addExpection.fulfill()
//		}
//		waitForExpectations(timeout: 5, handler: nil)
//		
//		guard let addFolders = account.folders else {
//			XCTFail()
//			return
//		}
//		
//		XCTAssertEqual(10, addFolders.count)
//		let addFolderNames = addFolders.map { $0.name ?? "" }
//		XCTAssertTrue(addFolderNames.contains("Vanlife"))
//
//		TestAccountManager.shared.deleteAccount(account)
//		
//	}
//
//}
