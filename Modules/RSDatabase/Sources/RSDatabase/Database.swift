//
//  Database.swift
//  RSDatabase
//
//  Created by Brent Simmons on 12/15/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation
import RSDatabaseObjC

/// Result type that provides an FMDatabase or an Error.
public typealias DatabaseResult = Result<FMDatabase, Error>

/// Block that executes database code or handles an Error.
public typealias DatabaseBlock = @Sendable (DatabaseResult) -> Void

/// Completion block that provides an optional Error.
public typealias DatabaseCompletionBlock = @Sendable (Error?) -> Void

/// Dictionary representing one row of database values, keyed by column name.
public typealias DatabaseDictionary = [String: Any]

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
	var error: Error? {
		switch self {
		case .success:
			return nil
		case .failure(let error):
			return error
		}
	}
}
