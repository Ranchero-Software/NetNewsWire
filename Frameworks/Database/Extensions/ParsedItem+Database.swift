//
//  ParsedItem+Database.swift
//  Database
//
//  Created by Brent Simmons on 9/2/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser
import Data

extension ParsedItem {

	func databaseIdentifierWithFeed(_ feed: Feed) -> String {

		if let identifier = syncServiceID {
			return identifier
		}

		// Must be, and is, the same calculation as in Article.init.
		return databaseIDWithString("\(feed.feedID) \(uniqueID)")
	}
}




