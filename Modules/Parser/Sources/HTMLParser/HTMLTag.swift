//
//  HTMLTag.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public typealias HTMLTagAttributes = [String: String]

public struct HTMLTag: Sendable {

	public enum TagType: Sendable {
		case link
		case meta
	}

	public let tagType: TagType
	public let attributes: HTMLTagAttributes?

	public init(tagType: TagType, attributes: HTMLTagAttributes?) {
		self.tagType = tagType
		self.attributes = attributes
	}
}
