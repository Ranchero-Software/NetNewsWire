//
//  FeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// FeedParser knows about the various syndication feed types.
// It might be a good idea to do a plugin-style architecture here instead —
// but feed formats don’t appear all that often, so it’s probably not necessary.

public struct FeedParser {

	static let minNumberOfBytesRequired = 128

	public static func feedType(parserData: ParserData) -> FeedType {

		// Can call with partial data — while still downloading, for instance.
		// If there’s not enough data, return .unknown. Ask again when there’s more data.
		// If it’s definitely not a feed, return .notAFeed.

		if parserData.data.count < minNumberOfBytesRequired {
			return .unknown
		}

		if parserData.data.isProbablyJSONFeed() {
			return .jsonFeed
		}
		if parserData.data.isProbablyRSSInJSON() {
			return .rssInJSON
		}

		if parserData.data.isProbablyHTML() {
			return .notAFeed
		}

		if parserData.data.isProbablyRSS() {
			return .rss
		}
		if parserData.data.isProbablyAtom() {
			return .atom
		}

		return .notAFeed
	}

	public static func parseFeed(parserData: ParserData) -> ParsedFeed? {

		let type = feedType(parserData)

		switch type {

		case .jsonFeed:
			return JSONFeedParser.parse(parserData)

		case .rssInJSON:
			return RSSInJSONFeedParser.parse(parserData)

		case .rss:
			return RSSParser.parse(parserData)

		case .atom:
			return AtomParser.parser(parserData)

		case .unknown, .notAFeed:
			return nil
		}
	}
}
