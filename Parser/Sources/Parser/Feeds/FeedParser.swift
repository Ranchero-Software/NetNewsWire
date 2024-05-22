//
//  FeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ParserObjC

// FeedParser handles RSS, Atom, JSON Feed, and RSS-in-JSON.
// You don’t need to know the type of feed.

public struct FeedParser {

	public static func canParse(_ parserData: ParserData) -> Bool {

		let type = feedType(parserData)

		switch type {
		case .jsonFeed, .rssInJSON, .rss, .atom:
			return true
		default:
			return false
		}
	}

	public static func parse(_ parserData: ParserData) async throws -> ParsedFeed? {

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

	/// For unit tests measuring performance.
	public static func parseSync(_ parserData: ParserData) throws -> ParsedFeed? {

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

}
