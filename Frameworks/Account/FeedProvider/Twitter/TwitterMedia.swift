//
//  TwitterMedia.swift
//  Account
//
//  Created by Maurice Parker on 4/20/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterMedia: Codable, TwitterEntity {
	
	let indices: [Int]?

	enum CodingKeys: String, CodingKey {
		case indices = "indices"
	}
	
	func renderAsHTML() -> String {
		return String()
	}
}
