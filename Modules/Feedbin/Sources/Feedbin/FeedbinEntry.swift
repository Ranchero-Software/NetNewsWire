//
//  FeedbinArticle.swift
//  Account
//
//  Created by Brent Simmons on 12/11/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser
import ParserObjC

public final class FeedbinEntry: Decodable, @unchecked Sendable {

	public let articleID: Int
	public let feedID: Int
	public let title: String?
	public let url: String?
	public let authorName: String?
	public let contentHTML: String?
	public let summary: String?
	public let datePublished: String?
	public let dateArrived: String?
	public let jsonFeed: FeedbinEntryJSONFeed?

	// Feedbin dates can't be decoded by the JSONDecoding 8601 decoding strategy. Feedbin
	// requires a very specific date formatter to work and even then it fails occasionally.
	// Rather than loose all the entries we only lose the one date by decoding as a string
	// and letting the one date fail when parsed.
	public lazy var parsedDatePublished: Date? = {
		if let datePublished = datePublished {
			return RSDateWithString(datePublished)
		}
		else {
			return nil
		}
	}()

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

public struct FeedbinEntryJSONFeed: Decodable, Sendable {

	public let jsonFeedAuthor: FeedbinEntryJSONFeedAuthor?
	public let jsonFeedExternalURL: String?

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

public struct FeedbinEntryJSONFeedAuthor: Decodable, Sendable {

	public let url: String?
	public let avatarURL: String?
	
	enum CodingKeys: String, CodingKey {
		case url = "url"
		case avatarURL = "avatar"
	}
}
