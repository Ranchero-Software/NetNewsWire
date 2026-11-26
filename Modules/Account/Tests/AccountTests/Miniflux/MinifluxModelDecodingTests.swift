//
//  MinifluxModelDecodingTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
@testable import Account

struct MinifluxModelDecodingTests {

	@Test func entriesResponse() throws {
		let resourceURL = try #require(Bundle.module.resourceURL)
		let data = try Data(contentsOf: resourceURL.appendingPathComponent("JSON/miniflux_entries_page1.json"))
		let entries = try JSONDecoder().decode(MinifluxEntriesResponse.self, from: data).entries

		let unreadStarred = try #require(entries.first { $0.entryID == 5001 })
		#expect(unreadStarred.status == .unread)
		#expect(unreadStarred.starred == true)
		// published_at has fractional seconds, which JSONDecoder’s .iso8601 strategy can’t parse.
		#expect(unreadStarred.parsedDatePublished != nil)

		let read = try #require(entries.first { $0.entryID == 5002 })
		#expect(read.status == .read)

		let missingAuthor = try #require(entries.first { $0.entryID == 5003 })
		#expect(missingAuthor.author == nil)

		let emptyEnclosures = try #require(entries.first { $0.entryID == 5004 })
		#expect(emptyEnclosures.enclosures?.isEmpty == true)
		#expect(emptyEnclosures.attachments == nil)

		let withEnclosures = try #require(entries.first { $0.entryID == 5005 })
		let attachments = try #require(withEnclosures.attachments)
		#expect(attachments.map(\.url) == ["https://media.example/ep1.mp3", "https://media.example/ep1.jpg"])
		#expect(attachments.first?.sizeInBytes == 1234567)
		#expect(attachments.last?.sizeInBytes == nil)
		#expect(withEnclosures.imageURL == "https://media.example/ep1.jpg")
	}
}
