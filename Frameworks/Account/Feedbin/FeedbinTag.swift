//
//  FeedbinTag.swift
//  Account
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinTag: Codable, Equatable, Hashable {
	
	let tagID: Int
	let name: String
	
	enum CodingKeys: String, CodingKey {
		case tagID = "id"
		case name = "name"
	}
	
}
