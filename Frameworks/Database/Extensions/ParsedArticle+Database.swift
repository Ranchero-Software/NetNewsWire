//
//  ParsedArticle+Database.swift
//  Database
//
//  Created by Brent Simmons on 9/18/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser
import Data

extension ParsedItem {
	
	var articleID: String {
		if let s = syncServiceID {
			return s
		}
		// Must be same calculation as for Article.
		return Article.calculatedArticleID(feedID: feedURL, uniqueID: uniqueID)
	}
}
