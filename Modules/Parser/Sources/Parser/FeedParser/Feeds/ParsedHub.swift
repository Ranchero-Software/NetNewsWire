//
//  ParsedHub.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class ParsedHub: Hashable, Sendable {

	public let type: String
	public let url: String

	init(type: String, url: String) {
		self.type = type
		self.url = url
	}
	
	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(type)
		hasher.combine(url)
	}

	// MARK: - Equatable

	public static func ==(lhs: ParsedHub, rhs: ParsedHub) -> Bool {
		lhs.type == rhs.type && lhs.url == rhs.url
	}
}
