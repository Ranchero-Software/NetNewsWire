//
//  FeedbinTagging.swift
//  Account
//
//  Created by Brent Simmons on 10/14/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedbinTagging: Codable, Sendable {

	public let taggingID: Int
	public let feedID: Int
	public let name: String

	enum CodingKeys: String, CodingKey {
		case taggingID = "id"
		case feedID = "feed_id"
		case name = "name"
	}
}

public struct FeedbinCreateTagging: Codable, Sendable {

	public let feedID: Int
	public let name: String
	
	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
		case name = "name"
	}

	public init(feedID: Int, name: String) {

		self.feedID = feedID
		self.name = name
	}
}
