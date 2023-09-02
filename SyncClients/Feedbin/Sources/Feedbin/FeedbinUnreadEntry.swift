//
//  FeedbinUnreadEntry.swift
//  Account
//
//  Created by Maurice Parker on 5/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinUnreadEntry: Codable {
	
	let unreadEntries: [Int]
	
	enum CodingKeys: String, CodingKey {
		case unreadEntries = "unread_entries"
	}
	
}
