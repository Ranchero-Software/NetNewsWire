//
//  ReaderAPIUnreadEntry.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ReaderAPIReferenceWrapper: Codable {
	let itemRefs: [ReaderAPIReference]
	
	enum CodingKeys: String, CodingKey {
		case itemRefs = "itemRefs"
	}
}

struct ReaderAPIReference: Codable {
	
	let itemId: String
	
	enum CodingKeys: String, CodingKey {
		case itemId = "id"
	}
	
}
