//
//  HTMLTag.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// A `<link>` or `<meta>` tag collected during HTML metadata parsing.
// Keys in `attributes` preserve the source document's case; lookups should
// use case-insensitive matching.

public struct HTMLTag: Sendable {

	public enum TagType: Sendable {
		case link
		case meta
	}

	public let type: TagType
	public let attributes: [String: String]

	public init(type: TagType, attributes: [String: String]) {
		self.type = type
		self.attributes = attributes
	}
}
