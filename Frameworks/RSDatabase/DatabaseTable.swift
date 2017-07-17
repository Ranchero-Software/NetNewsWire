//
//  DatabaseTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 7/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DatabaseTable {
	
	public var name: String {get}
	
	public init(name: String)
}

extension DatabaseTable {
	
	public func selectRowsWhere(key: String, equals value: Any, in database: FMDatabase) -> FMResultSet? {
		
		return database.rs_selectRowsWhereKey(key, equalsValue: value, tableName: self.name)
	}
	
	public func deleteRowsWhere(key: String, equalsAnyValue values: [Any], in database: FMDatabase) {
		
		if values.isEmpty {
			return
		}
		
		database.rs_deleteRowsWhereKey(key, inValues: values, tableName: name)
	}
}
