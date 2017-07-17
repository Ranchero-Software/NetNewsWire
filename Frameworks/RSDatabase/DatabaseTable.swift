//
//  DatabaseTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct DatabaseTable {

	public let name: String

	public init(name: String) {

		self.name = name
	}

	public func selectRowsWhere(key: String, equals value: Any, in database: FMDatabase) -> FMResultSet? {

		return database.rs_selectRowsWhereKey(key, equalsValue: value, tableName: self.name)
 	}

}
