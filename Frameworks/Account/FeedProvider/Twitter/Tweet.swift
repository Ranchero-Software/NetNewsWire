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
	let displayTextRange: [Int]?
	let user: TwitterUser
	let truncated: Bool
	let retweeted: Bool
	let extendedTweet: ExtendedTweet?

	enum CodingKeys: String, CodingKey {
		case createdAt = "created_at"
		case idStr = "id_str"
		case text = "text"
		case displayTextRange = "display_text_range"
		case user = "user"
		case truncated = "truncated"
		case retweeted = "retweeted"
		case extendedTweet = "extended_tweet"
	}
	
}

struct ExtendedTweet: Codable {
	
	let fullText: String?
	let displayTextRange: [Int]?

	enum CodingKeys: String, CodingKey {
		case fullText = "full_text"
		case displayTextRange = "display_text_range"
	}
	
}
