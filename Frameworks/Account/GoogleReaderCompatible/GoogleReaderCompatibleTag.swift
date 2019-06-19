//
//  GoogleReaderCompatibleTag.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct GoogleReaderCompatibleTagContainer: Codable {
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
