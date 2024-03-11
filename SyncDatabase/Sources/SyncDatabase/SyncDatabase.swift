//
//  SyncDatabase.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Database

public struct SyncDatabase: Sendable {

	private let syncStatusTable: SyncStatusTable

	public init(databaseFilePath: String) {

		self.syncStatusTable = SyncStatusTable(databasePath: databaseFilePath)
	}

	// MARK: - API

	public func insertStatuses(_ statuses: [SyncStatus]) async throws {
		try await syncStatusTable.insertStatuses(statuses)
	}
	
	public func selectForProcessing(limit: Int? = nil) async throws -> Set<SyncStatus>? {
		try await syncStatusTable.selectForProcessing(limit: limit)
	}

	public func selectPendingCount() async throws -> Int? {
		try await syncStatusTable.selectPendingCount()
	}
	
	public func selectPendingReadStatusArticleIDs() async throws -> Set<String>? {
		try await syncStatusTable.selectPendingReadStatusArticleIDs()
	}

	public func selectPendingStarredStatusArticleIDs() async throws -> Set<String>? {
		try await syncStatusTable.selectPendingStarredStatusArticleIDs()
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
	///
	/// On Macs, suspend() and resume() do nothing. They’re not needed.
	public func suspend() async {
		await syncStatusTable.suspend()
	}

	/// Open the database and allow for running database calls again.
	public func resume() async {
		await syncStatusTable.resume()
	}
}

// MARK: - Compatibility

// Use the below until switching to the async version of the API.

public typealias SyncStatusesResult = Result<Array<SyncStatus>, DatabaseError>
public typealias SyncStatusesCompletionBlock = @Sendable (SyncStatusesResult) -> Void

public typealias SyncStatusArticleIDsResult = Result<Set<String>, DatabaseError>
public typealias SyncStatusArticleIDsCompletionBlock = @Sendable (SyncStatusArticleIDsResult) -> Void

extension SyncDatabase {

	public func insertStatuses(_ statuses: [SyncStatus], completion: @escaping DatabaseCompletionBlock) {

		Task {
			do {
				try await self.insertStatuses(statuses)
				completion(nil)
			} catch {
				completion(DatabaseError.suspended)
			}
		}
	}

	public func selectForProcessing(limit: Int? = nil, completion: @escaping SyncStatusesCompletionBlock) {

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

	public func selectPendingCount(completion: @escaping DatabaseIntCompletionBlock) {

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

	public func selectPendingReadStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {

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

	public func selectPendingStarredStatusArticleIDs(completion: @escaping SyncStatusArticleIDsCompletionBlock) {

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

	public func resetAllSelectedForProcessing(completion: DatabaseCompletionBlock? = nil) {

		Task {
			do {
				try await self.resetAllSelectedForProcessing()
				completion?(nil)
			} catch {
				completion?(DatabaseError.suspended)
			}
		}
	}

	public func resetSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {

		Task {
			do {
				try await self.resetSelectedForProcessing(articleIDs)
				completion?(nil)
			} catch {
				completion?(DatabaseError.suspended)
			}
		}
	}

	public func deleteSelectedForProcessing(_ articleIDs: [String], completion: DatabaseCompletionBlock? = nil) {

		Task {
			do {
				try await self.deleteSelectedForProcessing(articleIDs)
				completion?(nil)
			} catch {
				completion?(DatabaseError.suspended)
			}
		}
	}

	// MARK: - Suspend and Resume (for iOS)

	/// Close the database and stop running database calls.
	/// Any pending calls will complete first.
	public func suspend() {

		Task {
			await self.suspend()
		}
	}

	/// Open the database and allow for running database calls again.
	public func resume() {

		Task {
			await self.resume()
		}
	}
}
