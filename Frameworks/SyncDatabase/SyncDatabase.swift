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

	/// When SyncDatabase is suspended, database calls will crash the app.
	public var isSuspended: Bool {
		return queue.isSuspended
	}

	private let syncStatusTable: SyncStatusTable
	private let queue: DatabaseQueue

	public init(databaseFilePath: String) {
		let queue = DatabaseQueue(databasePath: databaseFilePath)
		queue.runCreateStatements(SyncDatabase.tableCreationStatements)
		queue.vacuumIfNeeded(daysBetweenVacuums: 11)
		self.queue = queue

		self.syncStatusTable = SyncStatusTable(queue: queue)
	}

	// MARK: - API

	public func insertStatuses(_ statuses: [SyncStatus], completionHandler: VoidCompletionBlock? = nil) {
		syncStatusTable.insertStatuses(statuses, completionHandler: completionHandler)
	}
	
	public func selectForProcessing() -> [SyncStatus] {
		return syncStatusTable.selectForProcessing()
	}
	
	public func selectPendingCount() -> Int {
		return syncStatusTable.selectPendingCount()
	}
	
	public func resetSelectedForProcessing(_ articleIDs: [String], completionHandler: VoidCompletionBlock? = nil) {
		syncStatusTable.resetSelectedForProcessing(articleIDs, completionHandler: completionHandler)
	}
	
    public func deleteSelectedForProcessing(_ articleIDs: [String], completionHandler: VoidCompletionBlock? = nil) {
		syncStatusTable.deleteSelectedForProcessing(articleIDs, completionHandler: completionHandler)
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
