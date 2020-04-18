//
//  TwitterMentions.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterMention {
	
	let name: String?
	let indices: [Int]?
	let screenName: String?
	let expandedURL: String?
	let idStr: String?
	
	enum CodingKeys: String, CodingKey {
		case name = "url"
		case indices = "indices"
		case screenName = "screen_name"
		case expandedURL = "expandedURL"
		case idStr = "idStr"
	}
	
}
