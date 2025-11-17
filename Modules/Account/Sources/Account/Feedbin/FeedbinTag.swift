//
//  FeedbinTag.swift
//  Account
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated struct FeedbinTag: Codable, Sendable {
	let tagID: Int
	let name: String

	enum CodingKeys: String, CodingKey {
		case tagID = "id"
		case name = "name"
	}
}

nonisolated struct FeedbinRenameTag: Codable, Sendable {
	let oldName: String
	let newName: String

	enum CodingKeys: String, CodingKey {
		case oldName = "old_name"
		case newName = "new_name"
	}
}

nonisolated struct FeedbinDeleteTag: Codable, Sendable {
	let name: String

	enum CodingKeys: String, CodingKey {
		case name
	}
}
