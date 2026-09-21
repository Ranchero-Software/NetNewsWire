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

		let pendingReadArticleIDs = try await syncDatabase.selectPendingReadStatusArticleIDs()
		#expect(pendingReadArticleIDs == ["1"])

		let pendingStarredArticleIDs = try await syncDatabase.selectPendingStarredStatusArticleIDs()
		#expect(pendingStarredArticleIDs == [])
	}

	/// A failing status send used to abort the whole refresh, so an account stopped
	/// receiving new articles for as long as the send kept failing.
	@Test func failingStatusSendDoesNotBlockArticleRefresh() async throws {
		TestingURLProtocol.setResponse("tags.json", file: "JSON/tags_add.json")
		TestingURLProtocol.setResponse("subscriptions.json", file: "JSON/subscriptions_initial.json")

		// Only the send fails. The status refresh GETs this same path and must still succeed,
		// which is why this registration names a method.
		TestingURLProtocol.setResponse(.init(statusCode: 422), forURLContaining: "unread_entries.json", httpMethod: HTTPMethod.post)

		let account = TestAccountManager.shared.createAccount(type: .feedbin)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}

		let syncDatabase = try #require(account.delegate as? FeedbinAccountDelegate).syncDatabase
		await syncDatabase.insertStatuses([SyncStatus(articleID: "1", key: .read, flag: false)])

		try await account.refreshAll()

		// The send really did fail, so its row is still queued.
		let pendingReadArticleIDs = try await syncDatabase.selectPendingReadStatusArticleIDs()
		#expect(pendingReadArticleIDs == ["1"])

		#expect(account.flattenedFeeds().count == 224)
	}
}
