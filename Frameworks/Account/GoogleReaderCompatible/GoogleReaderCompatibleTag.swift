//
//  GoogleReaderCompatibleTag.swift
//  Account
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct GoogleReaderCompatibleTagWrapper: Codable {
	let tags: [GoogleReaderCompatibleTag]
	
	enum CodingKeys: String, CodingKey {
		case tags = "tags"
	}
}

struct GoogleReaderCompatibleTag: Codable {
	
	let tagID: String
	let type: String?
	
	enum CodingKeys: String, CodingKey {
		case tagID = "id"
		case type = "type"
	}
	
}

struct GoogleReaderCompatibleRenameTag: Codable {
	
	let oldName: String
	let newName: String
	
	enum CodingKeys: String, CodingKey {
		case oldName = "old_name"
		case newName = "new_name"
	}
	
}

struct GoogleReaderCompatibleDeleteTag: Codable {
	
	let name: String
	
	enum CodingKeys: String, CodingKey {
		case name
	}
	
}
