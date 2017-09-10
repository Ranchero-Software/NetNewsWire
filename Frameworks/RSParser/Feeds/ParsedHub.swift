//
//  ParsedHub.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedHub: Hashable {

	public let type: String
	public let url: String
	public let hashValue: Int
	
	init(type: String, url: String) {
		
		self.type = type
		self.url = url
		self.hashValue = type.hashValue ^ url.hashValue
	}
	
	public static func ==(lhs: ParsedHub, rhs: ParsedHub) -> Bool {
		
		return lhs.type == rhs.type && lhs.url == rhs.url
	}
}
