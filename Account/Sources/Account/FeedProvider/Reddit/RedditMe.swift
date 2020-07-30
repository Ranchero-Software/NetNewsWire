//
//  RedditMe.swift
//  Account
//
//  Created by Maurice Parker on 5/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditMe: Codable {

	let name: String?
	
	enum CodingKeys: String, CodingKey {
		case name = "name"
	}
	
}
