//
//  MinifluxSyncRegressionTests.swift
//  AccountTests
//
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
import SyncDatabase
@testable import Account

@MainActor final class MinifluxSyncRegressionTests: XCTestCase {

	override func setUp() {
		TestingURLProtocol.reset()
	}

	func testFailedStarredSendKeepsItsQueuedStatusAfterReadSendSucceeds() async throws {
		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer { TestAccountManager.shared.deleteAccount(account) }
		account.endpointURL = URL(string: "https://miniflux.test")
		(account.delegate as! MinifluxAccountDelegate).accountSettings?.detectedServerVersion = "2.1.0"

		let databasePath = (account.dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		let database = SyncDatabase(databasePath: databasePath)
		await database.insertStatuses([
			SyncStatus(articleID: "5001", key: .read, flag: true),
			SyncStatus(articleID: "5001", key: .starred, flag: true)
		])
		TestingURLProtocol.setResponse(.init(statusCode: 204), forURLContaining: "/v1/entries", httpMethod: "PUT")
		TestingURLProtocol.setResponse(.init(statusCode: 500), forURLContaining: "/v1/entries/5001", httpMethod: "GET")

		do {
			try await account.sendArticleStatus()
			XCTFail("Expected the starred update to fail")
		} catch {
			let pendingRead = try await database.selectPendingReadStatusArticleIDs()
			let pendingStarred = try await database.selectPendingStarredStatusArticleIDs()
			XCTAssertEqual(pendingRead, [])
			XCTAssertEqual(pendingStarred, ["5001"])
		}
	}

	func testFailedInitialReconciliationIsRetried() async throws {
		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")
		TestingURLProtocol.setResponse(.init(statusCode: 500), forURLContaining: "/v1/entries/ids")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer { TestAccountManager.shared.deleteAccount(account) }
		account.endpointURL = URL(string: "https://miniflux.test")

		do {
			try await account.refreshAll()
			XCTFail("Expected initial reconciliation to fail")
		} catch {}
		let firstAttemptCount = TestingURLProtocol.requestCount(forURLContaining: "/v1/entries/ids")
		XCTAssertGreaterThan(firstAttemptCount, 0)

		TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids.json")
		try await account.refreshAll()

		XCTAssertGreaterThan(TestingURLProtocol.requestCount(forURLContaining: "/v1/entries/ids"), firstAttemptCount)
	}

	func testInitialReconciliationPreservesPendingLocalStatus() async {
		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer { TestAccountManager.shared.deleteAccount(account) }
		let delegate = account.delegate as! MinifluxAccountDelegate
		var markedOff = Set<String>()

		let changedCount = await delegate.syncArticleState(
			entryIDs: [],
			pendingArticleIDs: ["5001"],
			currentArticleIDs: { ["5001"] },
			markOn: { $0 },
			markOff: { articleIDs in
				markedOff = articleIDs
				return articleIDs
			}
		)

		XCTAssertTrue(markedOff.isEmpty)
		XCTAssertEqual(changedCount, 0)
	}
}
