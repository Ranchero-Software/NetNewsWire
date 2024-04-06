//
//  ReaderAPICompatibleTagging.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ReaderAPITagging: Codable, Sendable {

	public let taggingID: Int
	public let feedID: Int
	public let name: String

	enum CodingKeys: String, CodingKey {
		case taggingID = "id"
		case feedID = "feed_id"
		case name = "name"
	}

}

public struct ReaderAPICreateTagging: Codable, Sendable {

	public let feedID: Int
	public let name: String

	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
		case name = "name"
	}
	
}
