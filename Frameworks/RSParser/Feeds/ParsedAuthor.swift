//
//  ParsedAuthor.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedAuthor: Hashable {

	public let name: String?
	public let url: String?
	public let avatarURL: String?
	public let emailAddress: String?
	public let hashValue: Int
	
	init(name: String?, url: String?, avatarURL: String?, emailAddress: String?) {

		self.name = name
		self.url = url
		self.avatarURL = avatarURL
		self.emailAddress = emailAddress
		
		var stringToHash = ""
		stringToHash += name ?? ""
		stringToHash += url ?? ""
		stringToHash += avatarURL ?? ""
		stringToHash += emailAddress ?? ""
		self.hashValue = stringToHash.hashValue
	}
	
	public static func ==(lhs: ParsedAuthor, rhs: ParsedAuthor) -> Bool {
		
		return lhs.hashValue == rhs.hashValue && lhs.name == rhs.name && lhs.url == rhs.url && lhs.avatarURL == rhs.avatarURL && lhs.emailAddress == rhs.emailAddress
	}
}
