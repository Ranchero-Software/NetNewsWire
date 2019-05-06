//
//  FeedbinRenameTag.swift
//  Account
//
//  Created by Maurice Parker on 5/6/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinRenameTag: Codable {
	
	let oldName: String
	let newName: String

	enum CodingKeys: String, CodingKey {
		case oldName = "old_name"
		case newName = "new_name"
	}
	
}
