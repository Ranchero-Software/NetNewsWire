//
//  TwitterEntities.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterEntities: Codable {
	
	let hashtags: [TwitterHashtag]?
	let urls: [TwitterURL]?
	let userMentions: [TwitterMention]?
	let symbols: [TwitterSymbol]?

	enum CodingKeys: String, CodingKey {
		case hashtags = "hashtags"
		case urls = "urls"
		case userMentions = "user_mentions"
		case symbols = "symbols"
	}
	
}
