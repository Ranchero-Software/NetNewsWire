//
//  FeedbinFeed.swift
//  Account
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser

public struct FeedbinSubscription: Hashable, Codable, Sendable {

	public let subscriptionID: Int
	public let feedID: Int
	public let name: String?
	public let url: String
	public let homePageURL: String?
	public let jsonFeed: FeedbinSubscriptionJSONFeed?

	enum CodingKeys: String, CodingKey {
		case subscriptionID = "id"
		case feedID = "feed_id"
		case name = "title"
		case url = "feed_url"
		case homePageURL = "site_url"
		case jsonFeed = "json_feed"
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(subscriptionID)
	}
	
	public static func == (lhs: FeedbinSubscription, rhs: FeedbinSubscription) -> Bool {
		return lhs.subscriptionID == rhs.subscriptionID
	}
	
}

public struct FeedbinSubscriptionJSONFeed: Codable, Sendable {

	public let favicon: String?
	public let icon: String?

	enum CodingKeys: String, CodingKey {
		case favicon = "favicon"
		case icon = "icon"
	}
}

public struct FeedbinCreateSubscription: Codable, Sendable {

	public let feedURL: String

	enum CodingKeys: String, CodingKey {
		case feedURL = "feed_url"
	}

	public init(feedURL: String) {

		self.feedURL = feedURL
	}
}

public struct FeedbinUpdateSubscription: Codable, Sendable {

	public let title: String

	enum CodingKeys: String, CodingKey {
		case title
	}

	public init(title: String) {

		self.title = title
	}
}

public struct FeedbinSubscriptionChoice: Codable, Sendable {

	public let name: String?
	public let url: String
	
	enum CodingKeys: String, CodingKey {
		case name = "title"
		case url = "feed_url"
	}
	
}
