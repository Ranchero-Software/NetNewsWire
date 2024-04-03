//
//  RSSParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ParserObjC

// RSSParser wraps the Objective-C RSRSSParser.
//
// The Objective-C parser creates RSParsedFeed, RSParsedArticle, etc.
// This wrapper then creates ParsedFeed, ParsedItem, etc. so that it creates
// the same things that JSONFeedParser and RSSInJSONParser create.
//
// In general, you should see FeedParser.swift for all your feed-parsing needs.

public struct RSSParser {

	public static func parse(_ parserData: ParserData) -> ParsedFeed? {

		if let rsParsedFeed = RSRSSParser.parseFeed(with: parserData) {
			return RSParsedFeedTransformer.parsedFeed(rsParsedFeed)
		}
		return nil
	}
}
