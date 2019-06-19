//
//  ReaderAPICompatibleTagging.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct ReaderAPITagging: Codable {

	let taggingID: Int
	let feedID: Int
	let name: String

	enum CodingKeys: String, CodingKey {
		case taggingID = "id"
		case feedID = "feed_id"
		case name = "name"
	}

}

struct ReaderAPICreateTagging: Codable {
	
	let feedID: Int
	let name: String
	
	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
		case name = "name"
	}
	
}
