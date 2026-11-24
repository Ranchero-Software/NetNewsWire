//
//  MinifluxFeed.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// GET /v1/feeds → [{"id":311,"feed_url":"...","site_url":"...","title":"...",
//                   "category":{"id":39,...},"icon":{"feed_id":311,...},...}]
struct MinifluxFeed: Decodable, Sendable {
	let feedID: Int64
	let feedURL: String
	let siteURL: String?
	let title: String?
	let category: MinifluxCategory?

	enum CodingKeys: String, CodingKey {
		case feedID = "id"
		case feedURL = "feed_url"
		case siteURL = "site_url"
		case title
		case category
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		feedID = try container.decode(Int64.self, forKey: .feedID)
		feedURL = try container.decode(String.self, forKey: .feedURL)
		siteURL = try? container.decode(String.self, forKey: .siteURL)
		title = try? container.decode(String.self, forKey: .title)
		// Decoded leniently: older servers, or feeds mid-import, may omit or malform this.
		category = try? container.decode(MinifluxCategory.self, forKey: .category)
	}
}

struct MinifluxCreateFeed: Encodable, Sendable {
	let feedURL: String
	let categoryID: Int64

	enum CodingKeys: String, CodingKey {
		case feedURL = "feed_url"
		case categoryID = "category_id"
	}
}

struct MinifluxCreateFeedResponse: Decodable, Sendable {
	let feedID: Int64

	enum CodingKeys: String, CodingKey {
		case feedID = "feed_id"
	}
}

// Only non-nil properties are encoded, so callers can send a title-only or category-only update.
struct MinifluxUpdateFeed: Encodable, Sendable {
	let title: String?
	let categoryID: Int64?

	enum CodingKeys: String, CodingKey {
		case title
		case categoryID = "category_id"
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encodeIfPresent(title, forKey: .title)
		try container.encodeIfPresent(categoryID, forKey: .categoryID)
	}
}
