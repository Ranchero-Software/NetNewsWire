//
//  ReaderAPIUnreadEntry.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ReaderAPIReferenceWrapper: Codable {
	let itemRefs: [ReaderAPIReference]?
	let continuation: String?
	
	enum CodingKeys: String, CodingKey {
		case itemRefs = "itemRefs"
		case continuation = "continuation"
	}
}

struct ReaderAPIReference: Codable {
	let itemId: String?
	
	enum CodingKeys: String, CodingKey {
		case itemId = "id"
	}
}
