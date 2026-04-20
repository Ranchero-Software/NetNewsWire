//
//  ParserData.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

import Foundation

// Raw bytes of something to parse plus the URL they came from, so parsers and
// scanners can resolve relative URLs against the source. Replaces the old
// Objective-C `ParserData` class — same public API so callers in Account,
// FeedFinder, and RSWeb need no changes.

public struct ParserData: Sendable {

	public let url: String
	public let data: Data

	public init(url: String, data: Data) {
		self.url = url
		self.data = data
	}
}
