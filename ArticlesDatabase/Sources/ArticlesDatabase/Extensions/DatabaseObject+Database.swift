//
//  DatabaseObject+Database.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/13/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Database
import Articles

extension Array where Element == DatabaseObject {
	
	func asAuthors() -> Set<Author>? {
		let authors = Set(self.map { $0 as! Author })
		return authors.isEmpty ? nil : authors
	}
}
