//
//  DatabaseObject.swift
//  RSDatabase
//
//  Created by Brent Simmons on 8/7/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol DatabaseObject {

	var databaseID: String { get }

	func attachRelationshipWithObjects(_ objects: [DatabaseObject], name: String)
}

extension Array where Element == DatabaseObject {

	func dictionary() -> [String: DatabaseObject] {

		var d = [String: DatabaseObject]()
		for object in self {
			d[object.databaseID] = object
		}
		return d
	}
}
