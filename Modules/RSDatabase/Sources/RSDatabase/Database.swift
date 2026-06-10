//
//  Database.swift
//  RSDatabase
//
//  Created by Brent Simmons on 12/15/19.
//  Copyright © 2019 Brent Simmons. All rights reserved.
//

import Foundation
import RSDatabaseObjC

/// Block that executes database code.
public typealias DatabaseBlock = @Sendable (FMDatabase) -> Void

/// Completion block that provides an optional Error.
public typealias DatabaseCompletionBlock = @Sendable (Error?) -> Void

/// Dictionary representing one row of database values, keyed by column name.
public typealias DatabaseDictionary = [String: Any]
