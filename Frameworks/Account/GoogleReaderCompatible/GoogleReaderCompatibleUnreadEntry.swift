//
//  GoogleReaderCompatibleUnreadEntry.swift
//  Account
//
//  Created by Maurice Parker on 5/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct GoogleReaderCompatibleReferenceWrapper: Codable {
	let itemRefs: [GoogleReaderCompatibleReference]
	
	enum CodingKeys: String, CodingKey {
		case itemRefs = "itemRefs"
	}
}

struct GoogleReaderCompatibleReference: Codable {
	
	let itemId: String
	
	enum CodingKeys: String, CodingKey {
		case itemId = "id"
	}
	
}
