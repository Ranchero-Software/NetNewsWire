//
//  AccountInkwellSyncTest.swift
//  AccountTests
//
//  Created by Manton Reece on 3/11/26.
//

import XCTest
@testable import Account

@MainActor final class AccountInkwellSyncTest: XCTestCase {
	func testDownloadSync() async throws {
		let testTransport = TestTransport()
		testTransport.testFiles["https://micro.blog/feeds/v2/subscriptions.json"] = "JSON/subscriptions_initial.json"
		let account = TestAccountManager.shared.createAccount(type: .inkwell, transport: testTransport)

		try await account.refreshAll()

		XCTAssertEqual(224, account.flattenedFeeds().count)
		XCTAssertEqual(0, account.folders?.count ?? 0)
		XCTAssertTrue(account.behaviors.contains(.disallowFolderManagement))
		XCTAssertTrue(account.behaviors.contains(.disallowOPMLImports))

		let daringFireball = account.idToFeedDictionary["1296379"]
		XCTAssertEqual("Daring Fireball", daringFireball?.name)
		XCTAssertEqual("https://daringfireball.net/feeds/json", daringFireball?.url)
		XCTAssertEqual("https://daringfireball.net/", daringFireball?.homePageURL)

		TestAccountManager.shared.deleteAccount(account)
	}
}
