//
//  Database.swift
//  RSDatabase
//
//  Created by Brent Simmons on 12/15/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation

public enum DatabaseError: Error, Sendable {
	case suspended // On iOS, to support background refreshing, a database may be suspended.
}

// Compatibility — to be removed once we switch to structured concurrency

/// Completion block that provides an optional DatabaseError.
public typealias DatabaseCompletionBlock = @Sendable (DatabaseError?) -> Void

/// Result type for fetching an Int or getting a DatabaseError.
public typealias DatabaseIntResult = Result<Int, DatabaseError>

/// Completion block for DatabaseIntResult.
public typealias DatabaseIntCompletionBlock = @Sendable (DatabaseIntResult) -> Void
