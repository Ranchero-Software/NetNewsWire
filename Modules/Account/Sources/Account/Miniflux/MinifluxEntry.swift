//
//  MinifluxEntry.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser

// GET /v1/entries?limit=1 → {"total":2043,"entries":[{"id":121624,"feed_id":310,"status":"unread",
//   "hash":"...","title":"...","url":"...","published_at":"2026-07-07T05:12:06Z",
//   "created_at":"2026-07-07T05:13:22.668113Z","changed_at":"2026-07-07T05:13:22.668113Z",
//   "content":"...","author":"...","starred":false,"reading_time":1,"enclosures":[],
//   "feed":{...},"tags":[...]}]}
struct MinifluxEntry: Decodable, Sendable {
	let entryID: Int64
	let feedID: Int64
	let title: String?
	let url: String?
	let author: String?
	let contentHTML: String?
	let datePublished: String?
	let enclosures: [MinifluxEnclosure]?
	let status: String?
	let starred: Bool?

	// Miniflux emits ISO8601 dates with fractional seconds and offsets, which JSONDecoder’s
	// .iso8601 strategy can’t parse. Rather than lose the whole entry, decode the date as a
	// String and let DateParser take care of it — exactly like FeedbinEntry.parsedDatePublished.
	var parsedDatePublished: Date? {
		datePublished.flatMap { DateParser.date(from: $0) }
	}

	enum CodingKeys: String, CodingKey {
		case entryID = "id"
		case feedID = "feed_id"
		case title
		case url
		case author
		case contentHTML = "content"
		case datePublished = "published_at"
		case enclosures
		case status
		case starred
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		entryID = try container.decode(Int64.self, forKey: .entryID)
		feedID = try container.decode(Int64.self, forKey: .feedID)
		title = try? container.decode(String.self, forKey: .title)
		url = try? container.decode(String.self, forKey: .url)
		author = try? container.decode(String.self, forKey: .author)
		contentHTML = try? container.decode(String.self, forKey: .contentHTML)
		datePublished = try? container.decode(String.self, forKey: .datePublished)
		enclosures = try? container.decode([MinifluxEnclosure].self, forKey: .enclosures)
		status = try? container.decode(String.self, forKey: .status)
		starred = try? container.decode(Bool.self, forKey: .starred)
	}
}

struct MinifluxEnclosure: Decodable, Sendable {
	let url: String?
	let mimeType: String?

	enum CodingKeys: String, CodingKey {
		case url
		case mimeType = "mime_type"
	}
}

struct MinifluxEntriesResponse: Decodable, Sendable {
	let total: Int
	let entries: [MinifluxEntry]
}

// GET /v1/entries/ids?status=unread → {"total":1960,"entry_ids":[121634,121624,...]}
struct MinifluxEntryIDsResponse: Decodable, Sendable {
	let total: Int
	let entryIDs: [Int64]

	enum CodingKeys: String, CodingKey {
		case total = "total"
		case entryIDs = "entry_ids"
	}
}

struct MinifluxUpdateEntriesPayload: Encodable, Sendable {
	let entryIDs: [Int64]
	let status: String?
	let starred: Bool?

	enum CodingKeys: String, CodingKey {
		case entryIDs = "entry_ids"
		case status
		case starred
	}
}
