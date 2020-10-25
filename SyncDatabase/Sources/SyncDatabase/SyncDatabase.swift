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

public typealias SyncStatusesResult = Result<Array<SyncStatus>, DatabaseError>
public typealias SyncStatusesCompletionBlock = (SyncStatusesResult) -> Void

public typealias SyncStatusArticleIDsResult = Result<Set<String>, DatabaseError>
public typealias SyncStatusArticleIDsCompletionBlock = (SyncStatusArticleIDsResult) -> Void

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

	public func insertStatuses(_ statuses: [SyncStatus], completion: @escaping DatabaseCompletionBlock) {
		syncStatusTable.insertStatuses(statuses, completion: completion)
	}
	
	public func selectForProcessing(limit: Int? = nil, completion: @escaping SyncStatusesCompletionBlock) {
		return syncStatusTable.selectForProcessing(limit: limit, completion: completion)
	}

	public func selectPendingCount(completion: @escaping DatabaseIntCompletionBlock) {
		syncStatusTable.selectPendingCount(completion)
	}

    public func selectPendingReadStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {
        syncStatusTable.selectPendingReadStatusArticleIDs(completion: completion)
    }
    
    public func selectPendingStarredStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {
        syncStatusTable.selectPendingStarredStatusArticleIDs(completion: completion)
    }
    
	public func resetAllSelectedForProcessing(completion: DatabaseCompletionBlock? = nil) {
		syncStatusTable.resetAllSelectedForProcessing(completion: completion)
	}

	public func resetSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {
		syncStatusTable.resetSelectedForProcessing(articleIDs, completion: completion)
	}
	
    public func deleteSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {
		syncStatusTable.deleteSelectedForProcessing(articleIDs, completion: completion)
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
