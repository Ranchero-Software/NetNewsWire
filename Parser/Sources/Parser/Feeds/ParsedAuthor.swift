//
//  ParsedAuthor.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedAuthor: Hashable, Codable, Sendable {

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
}
