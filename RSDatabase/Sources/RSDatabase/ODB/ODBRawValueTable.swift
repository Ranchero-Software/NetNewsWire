//
//  ODBRawValueTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/13/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Use this when you’re just getting/setting raw values from a table.

public final class ODBRawValueTable {

	let table: ODBTable

	init(table: ODBTable) {
		self.table = table
	}
	
	public subscript(_ name: String) -> Any? {
		get {
			return table.rawValue(name)
		}
		set {
			if let rawValue = newValue {
				table.set(rawValue, name: name)
			}
			else {
				table.delete(name: name)
			}
		}
	}

	public func string(for name: String) -> String? {
		return self[name] as? String
	}

	public func setString(_ stringValue: String?, for name: String) {
		self[name] = stringValue
	}
}
