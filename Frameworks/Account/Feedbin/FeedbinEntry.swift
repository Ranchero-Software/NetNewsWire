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

struct FeedbinEntry: Codable {

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

	// Feedbin dates can't be decoded by the JSONDecoding 8601 decoding strategy.  Feedbin
	// requires a very specific date formatter to work and even then it fails occasionally.
	// Rather than loose all the entries we only lose the one date by decoding as a string
	// and letting the one date fail when parsed.
	func parseDatePublished() -> Date? {
		if datePublished != nil  {
			return FeedbinDate.formatter.date(from: datePublished!)
		} else {
			return nil
		}
	}
	
}

struct FeedbinEntryJSONFeed: Codable {
	let jsonFeedAuthor: FeedbinEntryJSONFeedAuthor?
	enum CodingKeys: String, CodingKey {
		case jsonFeedAuthor = "author"
	}
}

struct FeedbinEntryJSONFeedAuthor: Codable {
	let url: String?
	let avatarURL: String?
	enum CodingKeys: String, CodingKey {
		case url = "url"
		case avatarURL = "avatar"
	}
}
