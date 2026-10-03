//
//  MinifluxModelDecodingTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

@MainActor final class MinifluxModelDecodingTests: XCTestCase {

	func testDecodeUser() throws {
		let user = try decode(MinifluxUser.self, from: "miniflux_me.json")
		XCTAssertEqual(35, user.id)
		XCTAssertEqual("testuser", user.username)
	}

	func testDecodeCategories() throws {
		let categories = try decode([MinifluxCategory].self, from: "miniflux_categories_initial.json")
		XCTAssertEqual(3, categories.count)

		guard let all = categories.first(where: { $0.title == "All" }) else {
			XCTFail("Expected an “All” category")
			return
		}
		XCTAssertEqual(1, all.categoryID)

		guard let tech = categories.first(where: { $0.title == "Tech" }) else {
			XCTFail("Expected a “Tech” category")
			return
		}
		XCTAssertEqual(2, tech.categoryID)

		guard let news = categories.first(where: { $0.title == "News" }) else {
			XCTFail("Expected a “News” category")
			return
		}
		XCTAssertEqual(3, news.categoryID)
	}

	func testDecodeCategoriesAfterDelete() throws {
		let categories = try decode([MinifluxCategory].self, from: "miniflux_categories_delete.json")
		XCTAssertEqual(2, categories.count)
		XCTAssertFalse(categories.contains { $0.title == "News" })
	}

	func testDecodeFeeds() throws {
		let feeds = try decode([MinifluxFeed].self, from: "miniflux_feeds_initial.json")
		XCTAssertEqual(5, feeds.count)

		guard let feed = feeds.first(where: { $0.feedID == 101 }) else {
			XCTFail("Expected feed 101")
			return
		}
		XCTAssertEqual("https://miniflux.test/feeds/general.xml", feed.feedURL)
		XCTAssertEqual("https://general.example", feed.siteURL)
		XCTAssertEqual("General Feed", feed.title)
		XCTAssertEqual(1, feed.category?.categoryID)
		XCTAssertEqual("All", feed.category?.title)

		// Feed 105 has no "icon" key at all — confirms lenient decoding tolerates its absence.
		guard let feedWithoutIcon = feeds.first(where: { $0.feedID == 105 }) else {
			XCTFail("Expected feed 105")
			return
		}
		XCTAssertEqual(1, feedWithoutIcon.category?.categoryID)

		let categoryIDs = Set(feeds.compactMap { $0.category?.categoryID })
		XCTAssertEqual(Set([1, 2, 3]), categoryIDs)
	}

	func testDecodeEntriesResponse() throws {
		let response = try decode(MinifluxEntriesResponse.self, from: "miniflux_entries_page1.json")
		XCTAssertEqual(5, response.total)
		XCTAssertEqual(5, response.entries.count)

		guard let unreadStarred = response.entries.first(where: { $0.entryID == 5001 }) else {
			XCTFail("Expected entry 5001")
			return
		}
		XCTAssertEqual(101, unreadStarred.feedID)
		XCTAssertEqual("Jane Doe", unreadStarred.author)
		XCTAssertEqual("unread", unreadStarred.status)
		XCTAssertEqual(true, unreadStarred.starred)
		// published_at has fractional seconds — confirms DateParser (not JSONDecoder's
		// .iso8601 strategy) is what's doing the parsing.
		XCTAssertNotNil(unreadStarred.parsedDatePublished)

		guard let readEntry = response.entries.first(where: { $0.entryID == 5002 }) else {
			XCTFail("Expected entry 5002")
			return
		}
		XCTAssertEqual("read", readEntry.status)
		XCTAssertEqual(false, readEntry.starred)

		guard let missingAuthor = response.entries.first(where: { $0.entryID == 5003 }) else {
			XCTFail("Expected entry 5003")
			return
		}
		XCTAssertNil(missingAuthor.author)

		guard let emptyEnclosures = response.entries.first(where: { $0.entryID == 5004 }) else {
			XCTFail("Expected entry 5004")
			return
		}
		XCTAssertNotNil(emptyEnclosures.enclosures)
		XCTAssertEqual(0, emptyEnclosures.enclosures?.count ?? -1)

		guard let withEnclosure = response.entries.first(where: { $0.entryID == 5005 }) else {
			XCTFail("Expected entry 5005")
			return
		}
		guard let enclosure = withEnclosure.enclosures?.first else {
			XCTFail("Expected an enclosure on entry 5005")
			return
		}
		XCTAssertEqual("https://media.example/ep1.mp3", enclosure.url)
		XCTAssertEqual("audio/mpeg", enclosure.mimeType)
	}

	func testDecodeEntryIDsResponse() throws {
		let response = try decode(MinifluxEntryIDsResponse.self, from: "miniflux_entry_ids.json")
		XCTAssertEqual(3, response.total)
		XCTAssertEqual([5001, 5003, 5004], response.entryIDs)
	}

	func testDecodeErrorResponse() throws {
		let json = Data(#"{"error_message": "This feed already exists (feed_id: 123)"}"#.utf8)
		let error = try JSONDecoder().decode(MinifluxErrorResponse.self, from: json)
		XCTAssertEqual("This feed already exists (feed_id: 123)", error.errorMessage)
	}

	func testDecodeVersionResponse() throws {
		let response = try decode(MinifluxVersionResponse.self, from: "miniflux_version.json")
		XCTAssertEqual("2.3.2", response.version)
	}
}

// MARK: - Fixture loading

private extension MinifluxModelDecodingTests {

	func decode<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
		let fileURL = Bundle.module.resourceURL!.appendingPathComponent("JSON/\(fileName)")
		let data = try Data(contentsOf: fileURL)
		return try JSONDecoder().decode(T.self, from: data)
	}
}
