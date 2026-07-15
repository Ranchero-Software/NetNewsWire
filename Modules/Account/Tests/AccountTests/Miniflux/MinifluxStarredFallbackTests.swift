//
//  MinifluxStarredFallbackTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
import Secrets
@testable import Account

@MainActor final class MinifluxStarredFallbackTests: XCTestCase {

	override func setUp() {
		TestingURLProtocol.reset()
	}

	func testFallbackOnlyTogglesEntriesWhoseStateDiffers() async throws {
		let accountSettings = AccountSettings(accountID: UUID().uuidString, dataFolder: NSTemporaryDirectory())
		accountSettings.endpointURL = URL(string: "https://miniflux.test")
		accountSettings.detectedServerVersion = "2.1.0" // Below entryIDsMinimumVersion.

		let caller = MinifluxAPICaller()
		caller.credentials = Credentials(type: .minifluxAPIToken, username: "", secret: "token")
		caller.accountSettings = accountSettings

		// 5001 is already starred; 5002 is not.
		TestingURLProtocol.setResponse("/v1/entries/5001", file: "JSON/miniflux_entry_5001_starred.json")
		TestingURLProtocol.setResponse("/v1/entries/5002", file: "JSON/miniflux_entry_5002_unstarred.json")

		try await caller.updateEntries(entryIDs: [5001, 5002], starred: true)

		XCTAssertFalse(TestingURLProtocol.requestedURLs.contains { $0.contains("/entries/5001/bookmark") })
		XCTAssertTrue(TestingURLProtocol.requestedURLs.contains { $0.contains("/entries/5002/bookmark") })
	}
}
