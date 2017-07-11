//
//  ArticleID.swift
//  Data
//
//  Created by Brent Simmons on 7/10/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

// Any given article’s unique ID is unique only for the feed it appears in.
// We can’t rely on feed authors to produce globally unique identifiers.
// So ArticleID includes the feedID as well as the uniqueID.
//
// While we could use a compound primary key in the database (feedID, articleID),
// that complicates things more than a bit. So ArticleID.stringValue provides
// a single value that can be used as a primary key.

public struct ArticleID: Hashable {
	
	public let feedID: String
	public let uniqueID: String
	public let stringValue: String // Stored in database
	public let hashValue: Int
	
	public init(feedID: String, uniqueID: String) {
		
		self.feedID = feedID
		self.uniqueID = uniqueID
		self.stringValue = "\(feedID) \(uniqueID)"
		self.hashValue = stringValue.hashValue
	}
	
	public static func ==(lhs: ArticleID, rhs: ArticleID) -> Bool {
		
		return lhs.hashValue == rhs.hashValue && lhs.feedID == rhs.uniqueID && lhs.feedID == rhs.feedID
	}
}

