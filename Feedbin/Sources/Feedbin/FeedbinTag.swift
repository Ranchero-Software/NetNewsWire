//
//  FeedbinTag.swift
//  Account
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedbinTag: Codable, Sendable {

	public let tagID: Int
	public let name: String

	enum CodingKeys: String, CodingKey {
		case tagID = "id"
		case name = "name"
	}
}

public struct FeedbinRenameTag: Codable, Sendable {

	public let oldName: String
	public let newName: String

	enum CodingKeys: String, CodingKey {
		case oldName = "old_name"
		case newName = "new_name"
	}

	public init(oldName: String, newName: String) {

		self.oldName = oldName
		self.newName = newName
	}
}

public struct FeedbinDeleteTag: Codable, Sendable {

	public let name: String
	
	enum CodingKeys: String, CodingKey {
		case name
	}
}
