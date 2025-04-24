//
//  FeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParserObjC

// FeedParser handles RSS, Atom, JSON Feed, and RSS-in-JSON.
// You don’t need to know the type of feed.

public typealias FeedParserCallback = (_ parsedFeed: ParsedFeed?, _ error: Error?) -> Void

public struct FeedParser {

	private static let parseQueue = DispatchQueue(label: "FeedParser parse queue")
	
	public static func canParse(_ parserData: ParserData) -> Bool {

		let type = feedType(parserData)

		switch type {
		case .jsonFeed, .rssInJSON, .rss, .atom:
			return true
		default:
			return false
		}
	}

	public static func mightBeAbleToParseBasedOnPartialData(_ parserData: ParserData) -> Bool {

		let type = feedType(parserData, isPartialData: true)

		switch type {
		case .jsonFeed, .rssInJSON, .rss, .atom, .unknown:
			return true
		default:
			return false
		}
	}

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

	public static func parse(_ parserData: ParserData, _ completion: @escaping FeedParserCallback) {

		parseQueue.async {
			do {
				let parsedFeed = try parse(parserData)
				DispatchQueue.main.async {
					completion(parsedFeed, nil)
				}
			}
			catch {
				DispatchQueue.main.async {
					completion(nil, error)
				}
			}
		}
	}
}
