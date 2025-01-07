//
//  FeedbinTag.swift
//  Account
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinTag: Codable {
	
	let tagID: Int
	let name: String
	
	enum CodingKeys: String, CodingKey {
		case tagID = "id"
		case name = "name"
	}
	
}

struct FeedbinRenameTag: Codable {
	
	let oldName: String
	let newName: String
	
	enum CodingKeys: String, CodingKey {
		case oldName = "old_name"
		case newName = "new_name"
	}
	
}

struct FeedbinDeleteTag: Codable {
	
	let name: String
	
	enum CodingKeys: String, CodingKey {
		case name
	}
	
}
