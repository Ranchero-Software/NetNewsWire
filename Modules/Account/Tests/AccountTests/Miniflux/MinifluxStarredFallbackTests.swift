//
//  MinifluxStarredFallbackTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSWeb
import Secrets
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct MinifluxStarredFallbackTests {

	@Test func fallbackOnlyTogglesEntriesWhoseStateDiffers() async throws {
		let accountSettings = AccountSettings(accountID: UUID().uuidString, dataFolder: NSTemporaryDirectory())
		defer {
			accountSettings.deleteSettings()
		}
		accountSettings.endpointURL = URL(string: "https://miniflux.test")
		accountSettings.detectedServerVersion = "2.1.0"

		let caller = MinifluxAPICaller()
		caller.credentials = Credentials(type: .minifluxAPIToken, username: "", secret: "token")
		caller.accountSettings = accountSettings

		// 5001 is already starred, and 5002 isn’t.
		TestingURLProtocol.setResponse("/v1/entries/5001", file: "JSON/miniflux_entry_5001_starred.json")
		TestingURLProtocol.setResponse("/v1/entries/5002", file: "JSON/miniflux_entry_5002_unstarred.json")

		try await caller.updateEntries(entryIDs: [5001, 5002], starred: true)

		#expect(TestingURLProtocol.requestCount(forURLContaining: "/entries/5001/bookmark") == 0)
		#expect(TestingURLProtocol.requestCount(forURLContaining: "/entries/5002/bookmark") > 0)
	}
}
