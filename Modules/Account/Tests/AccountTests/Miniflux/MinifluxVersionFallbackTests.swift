//
//  MinifluxVersionFallbackTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
@testable import Account

@MainActor final class MinifluxVersionFallbackTests: XCTestCase {

	override func setUp() {
		TestingURLProtocol.reset()
	}

	/// On a server older than `entryIDsMinimumVersion`, `/v1/entries/ids` isn’t stubbed at
	/// all — if the gating logic wrongly tried to use it, `refreshAll()` would throw. Instead
	/// the initial sync's reconciliation must fall back to paging `/v1/entries`.
	func testInitialSyncOnOldServerFallsBackToPagedEntries() async throws {
		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version_old.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		let unreadArticleIDs = await account.fetchUnreadArticleIDsAsync()
		let starredArticleIDs = await account.fetchStarredArticleIDsAsync()
		XCTAssertTrue(unreadArticleIDs.contains("5001"))
		XCTAssertTrue(starredArticleIDs.contains("5001"))

		TestAccountManager.shared.deleteAccount(account)
	}

	/// On a current server, the initial sync's reconciliation should still use
	/// `/v1/entries/ids` rather than the paged fallback.
	func testInitialSyncOnCurrentServerStillUsesEntryIDsEndpoint() async throws {
		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		XCTAssertTrue(TestingURLProtocol.requestedURLs.contains { $0.contains("/v1/entries/ids") })

		let unreadArticleIDs = await account.fetchUnreadArticleIDsAsync()
		let starredArticleIDs = await account.fetchStarredArticleIDsAsync()
		XCTAssertTrue(unreadArticleIDs.contains("5001"))
		XCTAssertTrue(starredArticleIDs.contains("5001"))

		TestAccountManager.shared.deleteAccount(account)
	}
}
