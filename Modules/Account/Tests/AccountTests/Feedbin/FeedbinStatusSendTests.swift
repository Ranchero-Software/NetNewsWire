//
//  FeedbinStatusSendTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/5/26.
//

import Testing
import RSWeb
import SyncDatabase
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct FeedbinStatusSendTests {

	/// A permanently-rejected unread status used to abort the remaining groups,
	/// so starring and unstarring never reached the server again.
	@Test func failingUnreadGroupStillSendsStarredGroup() async throws {
		// Matching is by URL substring, so both unread calls fail and both starred calls
		// fall through to the default 200.
		TestingURLProtocol.setResponse(.init(statusCode: 422), forURLContaining: "unread_entries.json")

		let account = TestAccountManager.shared.createAccount(type: .feedbin)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}

		let syncDatabase = try #require(account.delegate as? FeedbinAccountDelegate).syncDatabase
		await syncDatabase.insertStatuses([
			SyncStatus(articleID: "1", key: .read, flag: false),
			SyncStatus(articleID: "2", key: .starred, flag: true)
		])

		await #expect(throws: (any Error).self) {
			try await account.sendArticleStatus()
		}

		let pendingReadArticleIDs = await syncDatabase.selectPendingReadStatusArticleIDs()
		#expect(pendingReadArticleIDs == ["1"])

		let pendingStarredArticleIDs = await syncDatabase.selectPendingStarredStatusArticleIDs()
		#expect(pendingStarredArticleIDs == [])
	}
}
