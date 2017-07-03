//
//  Article+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

extension Article {
	
	convenience init?(row: FMResultSet) {
		
	}

	func databaseDictionary() -> NSDictionary {
		
		var d = NSMutableDictionary()
		
		
		return d.copy() as! NSDictionary
	}
}
