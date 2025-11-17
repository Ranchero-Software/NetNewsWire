//
//  FeedbinArticle.swift
//  Account
//
//  Created by Brent Simmons on 12/11/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

nonisolated final class FeedbinEntry: Decodable, Sendable {
	let articleID: Int
	let feedID: Int
	let title: String?
	let url: String?
	let authorName: String?
	let contentHTML: String?
	let summary: String?
	let datePublished: String?
	let dateArrived: String?
	let jsonFeed: FeedbinEntryJSONFeed?

	// Feedbin dates can't be decoded by the JSONDecoding 8601 decoding strategy. Feedbin
	// requires a very specific date formatter to work and even then it fails occasionally.
	// Rather than loose all the entries we only lose the one date by decoding as a string
	// and letting the one date fail when parsed.
	var parsedDatePublished: Date? {
		if let datePublished {
			return RSDateWithString(datePublished)
		}
		return nil
	}

	enum CodingKeys: String, CodingKey {
		case articleID = "id"
		case feedID = "feed_id"
		case title = "title"
		case url = "url"
		case authorName = "author"
		case contentHTML = "content"
		case summary = "summary"
		case datePublished = "published"
		case dateArrived = "created_at"
		case jsonFeed = "json_feed"
	}
}

nonisolated struct FeedbinEntryJSONFeed: Decodable, Sendable {
	let jsonFeedAuthor: FeedbinEntryJSONFeedAuthor?
	let jsonFeedExternalURL: String?

	enum CodingKeys: String, CodingKey {
		case jsonFeedAuthor = "author"
		case jsonFeedExternalURL = "external_url"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		do {
			jsonFeedAuthor = try container.decode(FeedbinEntryJSONFeedAuthor.self, forKey: .jsonFeedAuthor)
		} catch {
			jsonFeedAuthor = nil
		}
		do {
			jsonFeedExternalURL = try container.decode(String.self, forKey: .jsonFeedExternalURL)
		} catch {
			jsonFeedExternalURL = nil
		}
	}
}

nonisolated struct FeedbinEntryJSONFeedAuthor: Decodable, Sendable {
	let url: String?
	let avatarURL: String?

	enum CodingKeys: String, CodingKey {
		case url = "url"
		case avatarURL = "avatar"
	}
}
