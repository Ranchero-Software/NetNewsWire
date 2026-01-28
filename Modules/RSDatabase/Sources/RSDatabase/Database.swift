//
//  Database.swift
//  RSDatabase
//
//  Created by Brent Simmons on 12/15/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation
import RSDatabaseObjC

public enum DatabaseError: Error, LocalizedError, Sendable {
	case isSuspended // On iOS, to support background refreshing, a database may be suspended.

	public var errorDescription: String? {
		switch self {
		case .isSuspended:
			return NSLocalizedString("Database is suspended", comment: "Database suspended error")
		}
	}
}

/// Result type that provides an FMDatabase or a DatabaseError.
public typealias DatabaseResult = Result<FMDatabase, DatabaseError>

/// Block that executes database code or handles DatabaseQueueError.
public typealias DatabaseBlock = @Sendable (DatabaseResult) -> Void

/// Completion block that provides an optional DatabaseError.
public typealias DatabaseCompletionBlock = @Sendable (DatabaseError?) -> Void

/// Result type for fetching an Int or getting a DatabaseError.
public typealias DatabaseIntResult = Result<Int, DatabaseError>

/// Completion block for DatabaseIntResult.
public typealias DatabaseIntCompletionBlock = (DatabaseIntResult) -> Void

// MARK: - Extensions

public extension DatabaseResult {
	/// Convenience for getting the database from a DatabaseResult.
	var database: FMDatabase? {
		switch self {
		case .success(let database):
			return database
		case .failure:
			return nil
		}
	}

	/// Convenience for getting the error from a DatabaseResult.
	var error: DatabaseError? {
		switch self {
		case .success:
			return nil
		case .failure(let error):
			return error
		}
	}
}
