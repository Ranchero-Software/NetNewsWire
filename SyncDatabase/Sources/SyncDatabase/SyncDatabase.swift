//
//  SyncDatabase.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Database
import FMDB

public actor SyncDatabase {

	private var database: FMDatabase?
	private var databasePath: String
	private let syncStatusTable = SyncStatusTable()

	public init(databasePath: String) {

		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.runCreateStatements(Self.creationStatements)
		database.vacuum()

		self.database = database
		self.databasePath = databasePath
	}

	// MARK: - API

	public func insertStatuses(_ statuses: [SyncStatus]) throws {
		
		guard let database else {
			throw DatabaseError.suspended
		}
		syncStatusTable.insertStatuses(statuses, database: database)
	}
	
	public func selectForProcessing(limit: Int? = nil) throws -> Set<SyncStatus>? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return syncStatusTable.selectForProcessing(limit: limit, database: database)
	}

	public func selectPendingCount() throws -> Int? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return syncStatusTable.selectPendingCount(database: database)
	}
	
	public func selectPendingReadStatusArticleIDs() throws -> Set<String>? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return syncStatusTable.selectPendingReadStatusArticleIDs(database: database)
	}

	public func selectPendingStarredStatusArticleIDs() throws -> Set<String>? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return syncStatusTable.selectPendingStarredStatusArticleIDs(database: database)
	}

	public func resetAllSelectedForProcessing()  throws {

		guard let database else {
			throw DatabaseError.suspended
		}
		syncStatusTable.resetAllSelectedForProcessing(database: database)
	}

	public func resetSelectedForProcessing(_ articleIDs: [String]) throws {

		guard let database else {
			throw DatabaseError.suspended
		}
		syncStatusTable.resetSelectedForProcessing(articleIDs, database: database)
	}
	
    public func deleteSelectedForProcessing(_ articleIDs: [String]) throws {

		guard let database else {
			throw DatabaseError.suspended
		}
		syncStatusTable.deleteSelectedForProcessing(articleIDs, database: database)
	}

	// MARK: - Suspend and Resume (for iOS)

	public func suspend() {
#if os(iOS)
		database?.close()
		database = nil
#endif
	}

	public func resume() {
#if os(iOS)
		if database == nil {
			self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		}
#endif
	}
}

// MARK: - Compatibility

// Use the below until switching to the async version of the API.

public typealias SyncStatusesResult = Result<Array<SyncStatus>, DatabaseError>
public typealias SyncStatusesCompletionBlock = @Sendable (SyncStatusesResult) -> Void

public typealias SyncStatusArticleIDsResult = Result<Set<String>, DatabaseError>
public typealias SyncStatusArticleIDsCompletionBlock = @Sendable (SyncStatusArticleIDsResult) -> Void

public extension SyncDatabase {

	nonisolated func insertStatuses(_ statuses: [SyncStatus], completion: @escaping DatabaseCompletionBlock) {

		Task {
			do {
				try await self.insertStatuses(statuses)
				completion(nil)
			} catch {
				completion(DatabaseError.suspended)
			}
		}
	}

	nonisolated func selectForProcessing(limit: Int? = nil, completion: @escaping SyncStatusesCompletionBlock) {

		Task {
			do {
				if let syncStatuses = try await self.selectForProcessing(limit: limit) {
					completion(.success(Array(syncStatuses)))
				} else {
					completion(.success([SyncStatus]()))
				}
			} catch {
				completion(.failure(DatabaseError.suspended))
			}
		}
	}

	nonisolated func selectPendingCount(completion: @escaping DatabaseIntCompletionBlock) {

		Task {
			do {
				if let count = try await self.selectPendingCount() {
					completion(.success(count))
				} else {
					completion(.success(0))
				}

			} catch {
				completion(.failure(DatabaseError.suspended))
			}
		}
	}

	nonisolated func selectPendingReadStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {

		Task {
			do {
				if let articleIDs = try await self.selectPendingReadStatusArticleIDs() {
					completion(.success(articleIDs))
				} else {
					completion(.success(Set<String>()))
				}
			} catch {
				completion(.failure(DatabaseError.suspended))
			}
		}
	}

	nonisolated func selectPendingStarredStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {

		Task {
			do {
				if let articleIDs = try await self.selectPendingStarredStatusArticleIDs() {
					completion(.success(articleIDs))
				} else {
					completion(.success(Set<String>()))
				}
			} catch {
				completion(.failure(DatabaseError.suspended))
			}
		}
	}

	nonisolated func resetAllSelectedForProcessing(completion: DatabaseCompletionBlock? = nil) {

		Task {
			do {
				try await self.resetAllSelectedForProcessing()
				completion?(nil)
			} catch {
				completion?(DatabaseError.suspended)
			}
		}
	}

	nonisolated func resetSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {

		Task {
			do {
				try await self.resetSelectedForProcessing(articleIDs)
				completion?(nil)
			} catch {
				completion?(DatabaseError.suspended)
			}
		}
	}

	nonisolated func deleteSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {

		Task {
			do {
				try await self.deleteSelectedForProcessing(articleIDs)
				completion?(nil)
			} catch {
				completion?(DatabaseError.suspended)
			}
		}
	}
}

private extension SyncDatabase {

	static let creationStatements = """
 CREATE TABLE if not EXISTS syncStatus (articleID TEXT NOT NULL, key TEXT NOT NULL, flag BOOL NOT NULL DEFAULT 0, selected BOOL NOT NULL DEFAULT 0, PRIMARY KEY (articleID, key));
 """

}
