//
//  FeedbinFeed.swift
//  Account
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

nonisolated struct FeedbinSubscription: Hashable, Codable, Sendable {
	let subscriptionID: Int
	let feedID: Int
	let name: String?
	let url: String
	let homePageURL: String?
	let jsonFeed: FeedbinSubscriptionJSONFeed?

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

	static func == (lhs: FeedbinSubscription, rhs: FeedbinSubscription) -> Bool {
		return lhs.subscriptionID == rhs.subscriptionID
	}
}

nonisolated struct FeedbinSubscriptionJSONFeed: Codable, Sendable {
	let favicon: String?
	let icon: String?
	enum CodingKeys: String, CodingKey {
		case favicon = "favicon"
		case icon = "icon"
	}
}

nonisolated struct FeedbinCreateSubscription: Codable, Sendable {
	let feedURL: String
	enum CodingKeys: String, CodingKey {
		case feedURL = "feed_url"
	}
}

nonisolated struct FeedbinUpdateSubscription: Codable, Sendable {
	let title: String
	enum CodingKeys: String, CodingKey {
		case title
	}
}

nonisolated struct FeedbinSubscriptionChoice: Codable, Sendable {
	let name: String?
	let url: String

	enum CodingKeys: String, CodingKey {
		case name = "title"
		case url = "feed_url"
	}
}
