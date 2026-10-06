//
//  ParserData.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

import Foundation

/// Bytes to parse plus the originating URL,
/// so parsers can resolve relative URLs.
public struct ParserData: Sendable {

	public let url: String
	public let data: Data

	public init(url: String, data: Data) {
		self.url = url
		self.data = data
	}
}
