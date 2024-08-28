//
//  RSSParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SAX

public final class RSSParser {

	private var parseFeed: ParsedFeed?

	public static func parsedFeed(with parserData: ParserData) -> ParsedFeed? {

		let parser = RSSParser(parserData)
		parser.parse()
		return parser.parsedFeed
	}
}
