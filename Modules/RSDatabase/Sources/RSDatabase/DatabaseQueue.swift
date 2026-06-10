//
//  DatabaseQueue.swift
//  RSDatabase
//
//  Created by Brent Simmons on 11/13/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation
import os
import SQLite3
import RSDatabaseObjC

/// Manage a serial queue and a SQLite database.
public final class DatabaseQueue: Sendable {
	private struct State: @unchecked Sendable {
		var isCallingDatabase = false
		let database: FMDatabase

		init(_ database: FMDatabase) {
			self.database = database
		}
	}

	private let state: OSAllocatedUnfairLock<State>
	private let databasePath: String
	private let serialDispatchQueue: DispatchQueue

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DatabaseQueue")

	public init(databasePath: String) {
		Self.logger.debug("DatabaseQueue: creating with database path \(databasePath)")

		self.serialDispatchQueue = DispatchQueue(label: "DatabaseQueue (Serial) - \(databasePath)")

		self.databasePath = databasePath
		let database = FMDatabase(path: databasePath)!
		self.state = OSAllocatedUnfairLock(initialState: State(database))

		self.state.withLock { openDatabase($0.database) }
	}

	// MARK: - Make Database Calls

	/// Run a DatabaseBlock synchronously. This call will block the main thread
	/// potentially for a while, depending on how long it takes to execute
	/// the DatabaseBlock *and* depending on how many other calls have been
	/// scheduled on the queue. Use sparingly — prefer async versions.
	public func runInDatabaseSync(_ databaseBlock: DatabaseBlock) {
		serialDispatchQueue.sync {
			self.state.withLock { state in
				self._runInDatabase(&state, databaseBlock, false)
			}
		}
	}

	/// Run a DatabaseBlock asynchronously.
	public func runInDatabase(_ databaseBlock: @escaping DatabaseBlock) {
		serialDispatchQueue.async {
			self.state.withLock { state in
				self._runInDatabase(&state, databaseBlock, false)
			}
		}
	}

	/// Run a DatabaseBlock wrapped in a transaction synchronously.
	/// Transactions help performance significantly when updating the database.
	/// Nevertheless, it’s best to avoid this because it will block the main thread —
	/// prefer the async `runInTransaction` instead.
	public func runInTransactionSync(_ databaseBlock: @escaping DatabaseBlock) {
		serialDispatchQueue.sync {
			self.state.withLock { state in
				self._runInDatabase(&state, databaseBlock, true)
			}
		}
	}

	/// Run a DatabaseBlock wrapped in a transaction asynchronously.
	/// Transactions help performance significantly when updating the database.
	public func runInTransaction(_ databaseBlock: @escaping DatabaseBlock) {
		serialDispatchQueue.async {
			self.state.withLock { state in
				self._runInDatabase(&state, databaseBlock, true)
			}
		}
	}

	/// Run all the lines that start with "create".
	/// Use this to create tables, indexes, etc.
	public func runCreateStatements(_ statements: String) {
		runInDatabaseSync { database in
			Self.logger.debug("DatabaseQueue: runCreateStatements")

			statements.enumerateLines { (line, stop) in
				if line.lowercased().hasPrefix("create") {
					database.executeStatements(line)
				}
				stop = false
			}
		}
	}

	/// Compact the database. This should be done from time to time —
	/// weekly-ish? — to keep up the performance level of a database.
	/// Generally a thing to do at startup, if it’s been a while
	/// since the last vacuum() call.
	public func vacuum() async {
		await withCheckedContinuation { continuation in
			runInDatabase { database in
				database.vacuum()
				continuation.resume()
			}
		}
	}
}

private extension DatabaseQueue {

	private func _runInDatabase(_ state: inout State, _ databaseBlock: DatabaseBlock, _ useTransaction: Bool) {
		precondition(!state.isCallingDatabase)

		state.isCallingDatabase = true
		defer {
			state.isCallingDatabase = false
		}

		autoreleasepool {
			if useTransaction {
				state.database.beginTransaction()
			}
			databaseBlock(state.database)
			if useTransaction {
				state.database.commit()
			}
		}
	}

	func openDatabase(_ database: FMDatabase) {
		database.open()
		// All databases are single-connection and serialized — WAL gains us nothing
		// and produces extra -wal/-shm files that bloat on disk.
		database.executeStatements("PRAGMA journal_mode = DELETE;")
		database.executeStatements("PRAGMA synchronous = 1;")
		database.setShouldCacheStatements(true)
	}
}
