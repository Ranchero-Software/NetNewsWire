//
//  MinifluxEntryIDPagingTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 11/24/26.
//

import Foundation
import Testing
import RSWeb
import Secrets
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct MinifluxEntryIDPagingTests {

	/// Entry 1 is read on another device after the first page. Offset paging would then skip entry 3.
	@Test func pagingByEntryIDDoesNotSkipWhenUnreadSetShrinks() async throws {
		TestingURLProtocol.setResponse(entriesResponse(entryIDs: [1, 2], total: 4), forURLContaining: "after_entry_id=0")
		TestingURLProtocol.setResponse(entriesResponse(entryIDs: [3, 4], total: 2), forURLContaining: "after_entry_id=2")

		let accountSettings = AccountSettings(accountID: UUID().uuidString, dataFolder: NSTemporaryDirectory())
		defer {
			accountSettings.deleteSettings()
		}
		accountSettings.endpointURL = URL(string: "https://miniflux.test")
		accountSettings.detectedServerVersion = "2.1.0"

		let caller = MinifluxAPICaller()
		caller.credentials = Credentials(type: .minifluxAPIToken, username: "", secret: "token")
		caller.accountSettings = accountSettings

		let entryIDs = try await caller.retrieveUnreadEntryIDs()
		#expect(entryIDs == [1, 2, 3, 4])
	}
}

// MARK: - Helpers

private func entriesResponse(entryIDs: [Int64], total: Int) -> TestingURLProtocol.Response {
	let entries = entryIDs.map { "{\"id\": \($0), \"feed_id\": 1}" }.joined(separator: ", ")
	let json = "{\"total\": \(total), \"entries\": [\(entries)]}"
	return TestingURLProtocol.Response(data: Data(json.utf8))
}
