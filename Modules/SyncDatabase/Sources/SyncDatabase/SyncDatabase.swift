//
//  SyncDatabase.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import RSDatabaseObjC

public actor SyncDatabase {
	private let database: FMDatabase
	public nonisolated let databasePath: String

	public init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.runCreateStatements(Self.tableCreationStatements)
		database.vacuumIfNeeded()

		self.database = database
		self.databasePath = databasePath
	}

	// MARK: - API

	public func vacuum() {
		database.vacuum()
	}

	public func insertStatuses(_ statuses: Set<SyncStatus>) {
		try? SyncStatusTable.insertStatuses(statuses, database: database)
	}

	public func selectForProcessing(limit: Int? = nil) -> Set<SyncStatus>? {
		try? SyncStatusTable.selectForProcessing(limit: limit, database: database)
	}

	public func selectPendingCount() -> Int? {
		try? SyncStatusTable.selectPendingCount(database: database)
	}

	public func selectPendingReadStatusArticleIDs() -> Set<String>? {
		try? SyncStatusTable.selectPendingReadStatusArticleIDs(database: database)
	}

	public func selectPendingStarredStatusArticleIDs() -> Set<String>? {
		try? SyncStatusTable.selectPendingStarredStatusArticleIDs(database: database)
	}

	nonisolated public func resetAllSelectedForProcessing() {
		Task {
			await _resetAllSelectedForProcessing()
		}
	}

	/// Pass `key` when sending one status kind at a time. A nil key matches all kinds —
	/// correct only when every queued kind for these articleIDs was sent together.
	public func resetSelectedForProcessing(_ articleIDs: Set<String>, key: SyncStatus.Key? = nil) {
		try? SyncStatusTable.resetSelectedForProcessing(articleIDs, key: key, database: database)
	}

	public func deleteSelectedForProcessing(_ articleIDs: Set<String>, key: SyncStatus.Key? = nil) {
		try? SyncStatusTable.deleteSelectedForProcessing(articleIDs, key: key, database: database)
	}
}

// MARK: - Private

private extension SyncDatabase {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS syncStatus (articleID TEXT NOT NULL, key TEXT NOT NULL, flag BOOL NOT NULL DEFAULT 0, selected BOOL NOT NULL DEFAULT 0, PRIMARY KEY (articleID, key));
	"""

	func _resetAllSelectedForProcessing() {
		try? SyncStatusTable.resetAllSelectedForProcessing(database: database)
	}
}
