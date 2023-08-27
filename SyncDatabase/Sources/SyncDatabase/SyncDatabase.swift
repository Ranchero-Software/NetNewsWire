//
//  SyncDatabase.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase

public struct SyncDatabase {

	private let syncStatusTable: SyncStatusTable
	private let queue: DatabaseQueue

	public init(databaseFilePath: String) {
		let queue = DatabaseQueue(databasePath: databaseFilePath)
		try! queue.runCreateStatements(SyncDatabase.tableCreationStatements)
		queue.vacuumIfNeeded(daysBetweenVacuums: 11)
		self.queue = queue

		self.syncStatusTable = SyncStatusTable(queue: queue)
	}

	// MARK: - API

	public func insertStatuses(_ statuses: [SyncStatus]) async throws {
		try await syncStatusTable.insertStatuses(statuses)
	}

	public func selectForProcessing(limit: Int? = nil) async throws -> Set<SyncStatus> {
		try await syncStatusTable.selectForProcessing(limit: limit)
	}

	public func selectPendingCount() async throws -> Int {
		try await syncStatusTable.selectPendingCount()
	}

    public func selectPendingReadArticleIDs() async throws -> Set<String> {
        try await syncStatusTable.selectPendingReadArticleIDs()
    }

    public func selectPendingStarredArticleIDs() async throws -> Set<String> {
        try await syncStatusTable.selectPendingStarredArticleIDs()
    }

	public func resetAllSelectedForProcessing() async throws {
		try await syncStatusTable.resetAllSelectedForProcessing()
	}

	public func resetSelectedForProcessing(_ articleIDs: [String]) async throws {
		try await syncStatusTable.resetSelectedForProcessing(articleIDs)
	}

	public func deleteSelectedForProcessing(_ articleIDs: [String]) async throws {
		try await syncStatusTable.deleteSelectedForProcessing(articleIDs)
	}

	// MARK: - Suspend and Resume (for iOS)

	/// Close the database and stop running database calls.
	/// Any pending calls will complete first.
	public func suspend() {
		queue.suspend()
	}

	/// Open the database and allow for running database calls again.
	public func resume() {
		queue.resume()
	}
}

// MARK: - Private

private extension SyncDatabase {
	
	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS syncStatus (articleID TEXT NOT NULL, key TEXT NOT NULL, flag BOOL NOT NULL DEFAULT 0, selected BOOL NOT NULL DEFAULT 0, PRIMARY KEY (articleID, key));
	"""
}
