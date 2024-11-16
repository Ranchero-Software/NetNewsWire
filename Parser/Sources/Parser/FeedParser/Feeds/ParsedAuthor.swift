//
//  ParsedAuthor.swift
//  Parser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class ParsedAuthor: Hashable, Codable, Sendable {

	public let name: String?
	public let url: String?
	public let avatarURL: String?
	public let emailAddress: String?
	
	public init(name: String?, url: String?, avatarURL: String?, emailAddress: String?) {
		self.name = name
		self.url = url
		self.avatarURL = avatarURL
		self.emailAddress = emailAddress
	}

	/// Use when the actual property is unknown. Guess based on contents of the string. (This is common with RSS.)
	convenience init(singleString: String) {

		if singleString.contains("@") {
			self.init(name: nil, url: nil, avatarURL: nil, emailAddress: singleString)
		} else if singleString.lowercased().hasPrefix("http") {
			self.init(name: nil, url: singleString, avatarURL: nil, emailAddress: nil)
		} else {
			self.init(name: singleString, url: nil, avatarURL: nil, emailAddress: nil)
		}
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		if let name {
			hasher.combine(name)
		}
		else if let url {
			hasher.combine(url)
		}
		else if let emailAddress {
			hasher.combine(emailAddress)
		}
		else if let avatarURL{
			hasher.combine(avatarURL)
		}
		else {
			hasher.combine("")
		}
	}

	// MARK: - Equatable

	public static func ==(lhs: ParsedAuthor, rhs: ParsedAuthor) -> Bool {

		lhs.name == rhs.name && lhs.url == rhs.url && lhs.avatarURL == rhs.avatarURL && lhs.emailAddress == rhs.emailAddress
	}
}
