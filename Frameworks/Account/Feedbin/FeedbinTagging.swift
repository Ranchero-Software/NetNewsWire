//
//  FeedbinTagging.swift
//  Account
//
//  Created by Brent Simmons on 10/14/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinTagging: Codable {

	let taggingID: Int
	let feedID: Int
	let name: String

	enum CodingKeys: String, CodingKey {
		case taggingID = "id"
		case feedID = "feed_id"
		case name = "name"
	}

}

struct FeedbinCreateTagging: Codable {
	
	let feedID: Int
	let name: String
	
	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
		case name = "name"
	}
	
}
