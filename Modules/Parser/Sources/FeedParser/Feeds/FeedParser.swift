//
//  FeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SAX

// FeedParser handles RSS, Atom, JSON Feed, and RSS-in-JSON.
// You don’t need to know the type of feed.

public struct FeedParser {

	public static func canParse(_ parserData: ParserData) -> Bool {

		let type = FeedType.feedType(parserData.data)

		switch type {
		case .jsonFeed, .rssInJSON, .rss, .atom:
			return true
		default:
			return false
		}
	}

	public static func parse(_ parserData: ParserData) throws -> ParsedFeed? {

		let type = FeedType.feedType(parserData.data)

		switch type {

		case .jsonFeed:
			return nil // TODO: try JSONFeedParser.parse(parserData)

		case .rssInJSON:
			return nil // TODO: try RSSInJSONParser.parse(parserData)

		case .rss:
			let rssFeed = RSSParser.parsedFeed(with: parserData)
			return RSSFeedTransformer.parsedFeed(with: rssFeed)

		case .atom:
			return nil // TODO: AtomParser.parse(parserData)

		case .unknown, .notAFeed:
			return nil
		}
	}
}
