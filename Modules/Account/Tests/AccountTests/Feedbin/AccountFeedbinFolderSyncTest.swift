//
//  AccountFeedbinFolderSyncTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
@testable import Account

@MainActor final class AccountFeedbinFolderSyncTest: XCTestCase {

    override func setUp() {
		TestingURLProtocol.reset()
    }

    func testDownloadSync() async throws {

		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/tags.json", file: "JSON/tags_initial.json")
		let account = TestAccountManager.shared.createAccount(type: .feedbin)

		// Test initial folders
		try await account.refreshAll()

		guard let intialFolders = account.folders else {
			XCTFail()
			return
		}

		XCTAssertEqual(9, intialFolders.count)
		let initialFolderNames = intialFolders.map { $0.name ?? "" }
		XCTAssertTrue(initialFolderNames.contains("Outdoors"))

		// Test removing folders
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/tags.json", file: "JSON/tags_delete.json")

		try await account.refreshAll()

		guard let deleteFolders = account.folders else {
			XCTFail()
			return
		}

		XCTAssertEqual(8, deleteFolders.count)
		let deleteFolderNames = deleteFolders.map { $0.name ?? "" }
		XCTAssertTrue(deleteFolderNames.contains("Outdoors"))
		XCTAssertFalse(deleteFolderNames.contains("Tech Media"))

		// Test Adding Folders
		TestingURLProtocol.setResponse("https://api.feedbin.com/v2/tags.json", file: "JSON/tags_add.json")

		try await account.refreshAll()

		guard let addFolders = account.folders else {
			XCTFail()
			return
		}

		XCTAssertEqual(10, addFolders.count)
		let addFolderNames = addFolders.map { $0.name ?? "" }
		XCTAssertTrue(addFolderNames.contains("Vanlife"))

		TestAccountManager.shared.deleteAccount(account)

	}

}
