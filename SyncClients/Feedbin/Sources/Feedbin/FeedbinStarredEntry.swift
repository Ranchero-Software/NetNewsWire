//
//  FeedbinStarredEntry.swift
//  Account
//
//  Created by Maurice Parker on 5/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinStarredEntry: Codable {
	
	let starredEntries: [Int]
	
	enum CodingKeys: String, CodingKey {
		case starredEntries = "starred_entries"
	}
	
}
