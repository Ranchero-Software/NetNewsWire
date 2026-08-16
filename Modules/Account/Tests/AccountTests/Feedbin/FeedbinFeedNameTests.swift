//
//  FeedbinFeedNameTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 8/15/26.
//

import Testing
import RSWeb
@testable import Account

@MainActor struct FeedbinFeedNameTests {

	private static let daringFireballFeedID = "1296379"

	private let accountManager = TestAccountManager()

	@Test func refreshLeavesEditedNameAlone() async throws {
		TestingURLProtocol.reset()
		TestingURLProtocol.setResponse("tags.json", file: "JSON/tags_add.json")
		TestingURLProtocol.setResponse("subscriptions.json", file: "JSON/subscriptions_initial.json")

		let account = accountManager.createAccount(type: .feedbin)
		defer {
			accountManager.deleteAccount(account)
		}

		try await account.refreshAll()
		let feed = try #require(account.idToFeedDictionary[Self.daringFireballFeedID])
		feed.editedName = "Edited Name"

		// A second refresh sees the same server name and must not touch the rename.
		try await account.refreshAll()

		#expect(feed.editedName == "Edited Name")
		#expect(feed.name == "Daring Fireball")
		#expect(feed.nameForDisplay == "Edited Name")
	}
}
