//
//  RedditListing.swift
//  Account
//
//  Created by Maurice Parker on 5/3/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditListing: Codable {
	
	let name: String?
	
	enum CodingKeys: String, CodingKey {
		case name = "name"
	}
	
}
