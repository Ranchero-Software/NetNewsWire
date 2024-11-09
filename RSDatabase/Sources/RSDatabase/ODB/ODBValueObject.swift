//
//  ODBValueObject.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/21/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ODBValueObject: ODBObject, Hashable {

	let uniqueID: Int
	public let value: ODBValue

	// ODBObject protocol properties
	public let name: String
	public let parentTable: ODBTable?

	init(uniqueID: Int, parentTable: ODBTable, name: String, value: ODBValue) {

		self.uniqueID = uniqueID
		self.parentTable = parentTable
		self.name = name
		self.value = value
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(uniqueID)
		hasher.combine(value)
	}

	// MARK: - Equatable
	
	public static func ==(lhs: ODBValueObject, rhs: ODBValueObject) -> Bool {
		return lhs.uniqueID == rhs.uniqueID && lhs.value == rhs.value
	}
}
