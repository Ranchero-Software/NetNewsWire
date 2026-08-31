//
//  SyncStatusTableTests.swift
//  SyncDatabase
//
//  Created by Brent Simmons on 8/30/26.
//

import Foundation
import Testing
import SyncDatabase

@Suite struct SyncStatusTableTests {

	private let database = SyncDatabase(databasePath: ":memory:")

	/// Status syncing has to keep working on queues larger than SQLite’s
	/// expression-depth limit of 1000 terms.
	@Test func selectForProcessingHandlesLargeQueue() async throws {
		let articleIDCount = 1200
		let articleIDs = (0..<articleIDCount).map { "article-\($0)" }
		var statuses = Set<SyncStatus>()
		for articleID in articleIDs {
			statuses.insert(SyncStatus(articleID: articleID, key: .read, flag: true))
			statuses.insert(SyncStatus(articleID: articleID, key: .starred, flag: true))
		}
		await database.insertStatuses(statuses)

		let selectedStatuses = try #require(await database.selectForProcessing())
		#expect(selectedStatuses.count == articleIDCount * 2)

		// Only rows marked selected in the database are deleted, so an empty
		// pending count is what proves the marking happened.
		await database.deleteSelectedForProcessing(Set(articleIDs))
		#expect(await database.selectPendingCount() == 0)
	}

	@Test func selectForProcessingRespectsLimit() async throws {
		let limit = 150
		let statuses = Set((0..<300).map { SyncStatus(articleID: "article-\($0)", key: .read, flag: true) })
		await database.insertStatuses(statuses)

		let selectedStatuses = try #require(await database.selectForProcessing(limit: limit))
		#expect(selectedStatuses.count == limit)
	}

	@Test func selectForProcessingMatchesArticleIDAndKeyPairs() async throws {
		let articleID = "article-with-both"
		let statuses: Set<SyncStatus> = [
			SyncStatus(articleID: articleID, key: .read, flag: true),
			SyncStatus(articleID: articleID, key: .starred, flag: true)
		]
		await database.insertStatuses(statuses)

		let selectedStatuses = try #require(await database.selectForProcessing())
		#expect(selectedStatuses.count == 2)

		await database.deleteSelectedForProcessing([articleID], key: .read)
		#expect(await database.selectPendingCount() == 1)
		let pendingStarredArticleIDs = try #require(await database.selectPendingStarredStatusArticleIDs())
		#expect(pendingStarredArticleIDs == [articleID])
	}
}
