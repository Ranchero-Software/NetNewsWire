//
//  Tweet.swift
//  Account
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct Tweet: Codable {

	let createdAt: Date?
	let idStr: String?
	let text: String?
	let user: TwitterUser
	let truncated: Bool
	let extendedTweet: ExtendedTweet?

	enum CodingKeys: String, CodingKey {
		case createdAt = "created_at"
		case idStr = "id_str"
		case text = "text"
		case user = "user"
		case truncated = "truncated"
		case extendedTweet = "extended_tweet"
	}
	
}

struct ExtendedTweet: Codable {
	
	let full_text: String?
	
}
