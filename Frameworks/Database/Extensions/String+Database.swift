//
//  String+Database.swift
//  Database
//
//  Created by Brent Simmons on 8/20/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase

// A tag is a String.
// Extending tag to conform to DatabaseObject means extending String to conform to DatabaseObject.

extension String: DatabaseObject {
	
	public var databaseID: String {
		get {
			return self
		}
	}
}
