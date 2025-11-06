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
	private var database: FMDatabase?
	private let databasePath: String

	public init(databasePath: String) {
		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.runCreateStatements(Self.tableCreationStatements)
		database.vacuumIfNeeded(daysBetweenVacuums: 11, filepath: databasePath)

		self.database = database
		self.databasePath = databasePath
	}

	// MARK: - API

	public func insertStatuses(_ statuses: Set<SyncStatus>) throws {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		SyncStatusTable.insertStatuses(statuses, database: database)
	}

	public func selectForProcessing(limit: Int? = nil) throws -> Set<SyncStatus>? {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		return SyncStatusTable.selectForProcessing(limit: limit, database: database)
	}

	public func selectPendingCount() throws -> Int? {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		return SyncStatusTable.selectPendingCount(database: database)
	}

	public func selectPendingReadStatusArticleIDs() throws -> Set<String>? {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		return SyncStatusTable.selectPendingReadStatusArticleIDs(database: database)
	}

	public func selectPendingStarredStatusArticleIDs() throws -> Set<String>? {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		return SyncStatusTable.selectPendingStarredStatusArticleIDs(database: database)
	}

	nonisolated public func resetAllSelectedForProcessing() {
		Task {
			try? await _resetAllSelectedForProcessing()
		}
	}

	public func resetSelectedForProcessing(_ articleIDs: Set<String>) throws {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		SyncStatusTable.resetSelectedForProcessing(articleIDs, database: database)
	}

	public func deleteSelectedForProcessing(_ articleIDs: Set<String>) throws {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		SyncStatusTable.deleteSelectedForProcessing(articleIDs, database: database)
	}

	// MARK: - Suspend and Resume (for iOS)

	nonisolated public func suspend() {
#if os(iOS)
		Task {
			_suspend()
		}
#endif
	}

	nonisolated public func resume() {
#if os(iOS)
		Task {
			_resume()
		}
#endif
	}
}

// MARK: - Private

private extension SyncDatabase {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS syncStatus (articleID TEXT NOT NULL, key TEXT NOT NULL, flag BOOL NOT NULL DEFAULT 0, selected BOOL NOT NULL DEFAULT 0, PRIMARY KEY (articleID, key));
	"""

	func _resetAllSelectedForProcessing() throws {
		guard let database else {
			throw DatabaseError.isSuspended
		}
		SyncStatusTable.resetAllSelectedForProcessing(database: database)
	}

	func _suspend() {
#if os(iOS)
		database?.close()
		database = nil
#endif
	}

	func _resume() {
#if os(iOS)
		if database == nil {
			self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		}
#endif
	}
}
