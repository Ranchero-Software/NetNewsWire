//
//  MinifluxSyncRegressionTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSWeb
import SyncDatabase
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct MinifluxSyncRegressionTests {

	@Test func failedStarredSendKeepsItsQueuedStatusAfterReadSendSucceeds() async throws {
		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")
		let delegate = try #require(account.delegate as? MinifluxAccountDelegate)
		delegate.accountSettings?.detectedServerVersion = "2.1.0"

		let databasePath = (account.dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		let database = SyncDatabase(databasePath: databasePath)
		await database.insertStatuses([
			SyncStatus(articleID: "5001", key: .read, flag: true),
			SyncStatus(articleID: "5001", key: .starred, flag: true)
		])
		TestingURLProtocol.setResponse(.init(statusCode: 204), forURLContaining: "/v1/entries", httpMethod: "PUT")
		TestingURLProtocol.setResponse(.init(statusCode: 500), forURLContaining: "/v1/entries/5001", httpMethod: "GET")

		await #expect(throws: (any Error).self) {
			try await account.sendArticleStatus()
		}

		let pendingRead = try await database.selectPendingReadStatusArticleIDs()
		let pendingStarred = try await database.selectPendingStarredStatusArticleIDs()
		#expect(pendingRead == [])
		#expect(pendingStarred == ["5001"])
	}

	@Test func failedInitialReconciliationIsRetried() async throws {
		setFailingReconciliationResponses()

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")

		await #expect(throws: (any Error).self) {
			try await account.refreshAll()
		}
		let firstAttemptCount = TestingURLProtocol.requestCount(forURLContaining: "/v1/entries/ids")
		#expect(firstAttemptCount > 0)

		TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids.json")
		try await account.refreshAll()

		#expect(TestingURLProtocol.requestCount(forURLContaining: "/v1/entries/ids") > firstAttemptCount)
	}

	@Test func refreshAfterFailedInitialSyncSendsChangedAfter() async throws {
		setFailingReconciliationResponses()

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")

		await #expect(throws: (any Error).self) {
			try await account.refreshAll()
		}
		#expect(TestingURLProtocol.requestCount(forURLContaining: "changed_after") == 0)

		try? await account.refreshAll()

		#expect(TestingURLProtocol.requestCount(forURLContaining: "changed_after") > 0)
	}

	@Test func missingArticleHTTPErrorDoesNotFailRefresh() async throws {
		TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
		TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
		TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
		TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")
		TestingURLProtocol.setResponse("/v1/entries/ids", file: "JSON/miniflux_entry_ids_missing_article.json")
		TestingURLProtocol.setResponse(.init(statusCode: 500), forURLContaining: "/v1/entries/9001")

		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		account.endpointURL = URL(string: "https://miniflux.test")

		try await account.refreshAll()

		#expect(TestingURLProtocol.requestCount(forURLContaining: "/v1/entries/9001") > 0)
		#expect(account.lastRefreshCompletedDate != nil)
	}

	@Test func initialReconciliationPreservesPendingLocalStatus() async throws {
		let account = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		let delegate = try #require(account.delegate as? MinifluxAccountDelegate)
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

		#expect(markedOff.isEmpty)
		#expect(changedCount == 0)
	}
}

// MARK: - Helpers

/// The article fetch succeeds, then `/v1/entries/ids` returns 500.
private func setFailingReconciliationResponses() {
	TestingURLProtocol.setResponse("/v1/version", file: "JSON/miniflux_version.json")
	TestingURLProtocol.setResponse("/v1/categories", file: "JSON/miniflux_categories_initial.json")
	TestingURLProtocol.setResponse("/v1/feeds", file: "JSON/miniflux_feeds_initial.json")
	TestingURLProtocol.setResponse("/v1/entries?", file: "JSON/miniflux_entries_page1.json")
	TestingURLProtocol.setResponse(.init(statusCode: 500), forURLContaining: "/v1/entries/ids")
}
