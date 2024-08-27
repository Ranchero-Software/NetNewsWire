//
//  HTMLTag.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public struct HTMLTag: Sendable {

	public enum TagType: Sendable {
		case link
		case meta
	}

	public let tagType: TagType
	public let attributes: [String: String]?

	public init(tagType: TagType, attributes: [String : String]?) {
		self.tagType = tagType
		self.attributes = attributes
	}
}
