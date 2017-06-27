//
//  FeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// FeedParser handles RSS, Atom, JSON Feed, and RSS-in-JSON.
// You don’t need to know the type of feed.

public struct FeedParser {

	public static func parse(_ parserData: ParserData) throws -> ParsedFeed? {

		// This is generally fast enough to call on the main thread —
		// but it’s probably a good idea to use a background queue if
		// you might be doing a lot of parsing. (Such as in a feed reader.)

		do {
			let type = feedType(parserData)

			switch type {

			case .jsonFeed:
				return try JSONFeedParser.parse(parserData)

			case .rssInJSON:
				return try RSSInJSONParser.parse(parserData)

			case .rss:
				return RSSParser.parse(parserData)

			case .atom:
				return AtomParser.parse(parserData)

			case .unknown, .notAFeed:
				return nil
			}
		}
		catch { throw error }
	}
}
