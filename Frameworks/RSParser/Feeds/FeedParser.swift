//
//  FeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedParser {

	static func feedType(parserData: ParserData) -> FeedType {

		// If there’s not enough data, return .unknown. Ask again when there’s more data.
		// If it’s definitely not a feed, return .notAFeed.

		return .unknown //stub
	}

	static func parseFeed(parserData: ParserData) throws -> ParsedFeed? {


		return nil //stub
	}
}
