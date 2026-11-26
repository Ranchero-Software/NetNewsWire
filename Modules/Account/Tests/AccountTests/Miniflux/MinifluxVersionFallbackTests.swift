//
//  MinifluxVersionFallbackTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSWeb
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct MinifluxVersionFallbackTests {

	/// `/v1/entries/ids` isn’t stubbed, so the refresh would throw if an old server used it.
	@Test func initialSyncOnOldServerFallsBackToPagedEntries() async throws {
		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version_old.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		let unreadArticleIDs = await account.fetchUnreadArticleIDsAsync()
		let starredArticleIDs = await account.fetchStarredArticleIDsAsync()
		#expect(unreadArticleIDs.contains("5001"))
		#expect(starredArticleIDs.contains("5001"))
	}
}
