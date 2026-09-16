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

	/// The step check must not fire on a healthy read that simply found no rows.
	/// A false positive there would stop syncing outright.
	@Test func emptyQueueReadsCleanly() async throws {
		#expect(try #require(await database.selectForProcessing()).isEmpty)
		#expect(await database.selectPendingCount() == 0)
		#expect(try #require(await database.selectPendingReadStatusArticleIDs()).isEmpty)
		#expect(try #require(await database.selectPendingStarredStatusArticleIDs()).isEmpty)

		// And again once rows have been queued and then cleared.
		let statuses = Set((0..<5).map { SyncStatus(articleID: "article-\($0)", key: .read, flag: true) })
		await database.insertStatuses(statuses)
		_ = await database.selectForProcessing()
		await database.deleteSelectedForProcessing(Set(statuses.map { $0.articleID }), key: .read)

		#expect(try #require(await database.selectForProcessing()).isEmpty)
		#expect(await database.selectPendingCount() == 0)
	}

	/// A read that stops on a SQLite error has to fail, not return the rows it got to
	/// first. A short pending-statuses read is missing articleIDs that really are
	/// pending, and the next refresh reverts exactly those edits.
	///
	/// This covers failing on the first row. A failure partway through is the same bug
	/// and the same fix, but there’s no way to force one at a chosen row.
	@Test func aReadThatStopsOnAnErrorFails() async throws {
		let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
		defer {
			try? FileManager.default.removeItem(at: folderURL)
		}

		let database = SyncDatabase(databasePath: folderURL.appendingPathComponent("Sync.sqlite3").path)
		let articleIDs = (0..<10).map { "article-\($0)" }
		await database.insertStatuses(Set(articleIDs.map { SyncStatus(articleID: $0, key: .read, flag: true) }))

		// Every call fails once the folder is gone, but the statements still prepare
		// cleanly — the failure only shows up while stepping through the rows.
		try FileManager.default.removeItem(at: folderURL)

		#expect(await database.selectForProcessing() == nil)
		#expect(await database.selectPendingReadStatusArticleIDs() == nil)
	}
}
