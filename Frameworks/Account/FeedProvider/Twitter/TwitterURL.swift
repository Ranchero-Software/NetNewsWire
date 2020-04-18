//
//  TwitterURL.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterURL: Codable {
	
	let url: String?
	let indices: [Int]?
	let displayURL: String?
	let expandedURL: String?

	enum CodingKeys: String, CodingKey {
		case url = "url"
		case indices = "indices"
		case displayURL = "displayURL"
		case expandedURL = "expandedURL"
	}
	
}
