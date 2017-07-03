//
//  Folder+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data

extension Folder {
	
	func flattenedFeedIDs() -> [String] {
		
		return flattenedFeeds().map { $0.feedID }
	}
}
