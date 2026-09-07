//
//  FeedbinStatusSendTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/5/26.
//

import Foundation
import Testing
import RSWeb
import SyncDatabase
@testable import Account

@MainActor struct FeedbinStatusSendTests {

	/// A permanently-rejected unread status used to abort the remaining groups,
	/// so starring and unstarring never reached the server again.
	@Test func failingUnreadGroupStillSendsStarredGroup() async throws {
		TestingURLProtocol.reset()
		defer {
			TestingURLProtocol.reset()
		}

		// Matching is by URL substring, so both unread calls fail and both starred calls
		// fall through to the default 200.
		TestingURLProtocol.responses["unread_entries.json"] = TestingURLProtocol.Response(statusCode: 422)

		let account = TestAccountManager.shared.createAccount(type: .feedbin)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}

		let databasePath = URL(filePath: account.dataFolder).appendingPathComponent("Sync.sqlite3").path
		let syncDatabase = SyncDatabase(databasePath: databasePath)
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
