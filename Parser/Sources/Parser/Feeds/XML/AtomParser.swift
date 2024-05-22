//
//  AtomParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE
import ParserObjC
#endif

// RSSParser wraps the Objective-C RSAtomParser.
//
// The Objective-C parser creates RSParsedFeed, RSParsedArticle, etc.
// This wrapper then creates ParsedFeed, ParsedItem, etc. so that it creates
// the same things that JSONFeedParser and RSSInJSONParser create.
//
// In general, you should see FeedParser.swift for all your feed-parsing needs.

public struct AtomParser {

	public static func parse(_ parserData: ParserData) -> ParsedFeed? {

		if let rsParsedFeed = RSAtomParser.parseFeed(with: parserData) {
			return RSParsedFeedTransformer.parsedFeed(rsParsedFeed)
		}
		return nil
	}
}
