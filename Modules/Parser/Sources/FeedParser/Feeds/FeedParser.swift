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

	public static func canParse(_ data: Data) -> Bool {

		let type = FeedType.feedType(data)

		switch type {
		case .jsonFeed, .rssInJSON, .rss, .atom:
			return true
		default:
			return false
		}
	}

	public static func parse(urlString: String, data: Data) throws -> ParsedFeed? {

		let type = FeedType.feedType(data)

		switch type {

		case .jsonFeed:
			return try JSONFeedParser.parse(urlString: urlString, data: data)

		case .rssInJSON:
			return try RSSInJSONParser.parse(urlString: urlString, data: data)

		case .rss:
			let feed = RSSParser.parsedFeed(urlString: urlString, data: data)
			return RSSFeedTransformer.parsedFeed(with: feed, feedType: .rss)

		case .atom:
			let feed = AtomParser.parsedFeed(urlString: urlString, data: data)
			return RSSFeedTransformer.parsedFeed(with: feed, feedType: .atom)

		case .unknown, .notAFeed:
			return nil
		}
	}
}
