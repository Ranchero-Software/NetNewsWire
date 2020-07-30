//
//  TwitterSearchResult.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterSearchResult: Codable {
	
	let statuses: [TwitterStatus]?

	enum CodingKeys: String, CodingKey {
		case statuses = "statuses"
	}
}

