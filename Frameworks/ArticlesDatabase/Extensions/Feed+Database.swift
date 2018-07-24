//
//  Feed+Database.swift
//  Database
//
//  Created by Brent Simmons on 8/20/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

extension Set where Element == Feed {
	
	func feedIDs() -> Set<String> {
		
		return Set<String>(map { $0.feedID })
	}
}
