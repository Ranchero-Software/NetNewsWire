//
//  FeedlyUtilitiesTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 24/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Parser
@testable import Feedly

final class FeedlyUtilitiesTests: XCTestCase {

	// MARK: - Test parsedItemsKeyedByFeedURL

	func testParsedItemsKeyedByFeedURL_Empty() {

		let testDictionary = makeParsedItemTestDataFor(numberOfFeeds: 0, numberOfItemsInFeeds: 0)
		let parsedItems = parsedItemsFromDictionary(testDictionary)

		let resultDictionary = FeedlyUtilities.parsedItemsKeyedByFeedURL(parsedItems)
		let expectedDictionary = testDictionary
		XCTAssertEqual(resultDictionary, expectedDictionary)
	}
	
	func testParsedItemsKeyedByFeedURL_OneFeedOneItem() {

		let testDictionary = makeParsedItemTestDataFor(numberOfFeeds: 1, numberOfItemsInFeeds: 1)
		let parsedItems = parsedItemsFromDictionary(testDictionary)

		let resultDictionary = FeedlyUtilities.parsedItemsKeyedByFeedURL(parsedItems)
		let expectedDictionary = testDictionary
		XCTAssertEqual(resultDictionary, expectedDictionary)
	}
	
	func testParsedItemsKeyedByFeedURL_ManyFeedsManyItems() {
		
		let testDictionary = makeParsedItemTestDataFor(numberOfFeeds: 100, numberOfItemsInFeeds: 100)
		let parsedItems = parsedItemsFromDictionary(testDictionary)
		
		let resultDictionary = FeedlyUtilities.parsedItemsKeyedByFeedURL(parsedItems)
		let expectedDictionary = testDictionary
		XCTAssertEqual(resultDictionary, expectedDictionary)
	}
}

// MARK: - Private

private extension FeedlyUtilitiesTests {

	func makeParsedItemTestDataFor(numberOfFeeds: Int, numberOfItemsInFeeds: Int) -> [String: Set<ParsedItem>] {

		var d = [String: Set<ParsedItem>]()

		for feedIndex in 0..<numberOfFeeds {
			let feedID = "feed/\(feedIndex)"

			var items = Set<ParsedItem>()

			for parsedItemIndex in 0..<numberOfItemsInFeeds {
				let parsedItem = makeTestParsedItem(feedID, parsedItemIndex)
				items.insert(parsedItem)
			}

			d[feedID] = items
		}

		return d
	}

	func makeTestParsedItem(_ feedID: String, _ index: Int) -> ParsedItem {

		ParsedItem(syncServiceID: "\(feedID)/articles/\(index)", uniqueID: UUID().uuidString, feedURL: feedID, url: "http://localhost/", externalURL: "http://localhost/\(feedID)/articles/\(index).html", title: "Title\(index)", language: nil, contentHTML: "Content \(index) HTML.", contentText: "Content \(index) Text", summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: nil, dateModified: nil, authors: nil, tags: nil, attachments: nil)
	}

	func parsedItemsFromDictionary(_ d: [String: Set<ParsedItem>]) -> Set<ParsedItem> {

		var parsedItems = Set<ParsedItem>()

		for (_, value) in d {
			parsedItems.formUnion(value)
		}

		return parsedItems
	}
}
