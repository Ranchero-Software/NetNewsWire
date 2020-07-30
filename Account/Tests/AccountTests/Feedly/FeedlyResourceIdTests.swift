//
//  FeedlyResourceIdTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class FeedlyResourceIdTests: XCTestCase {
	
	func testFeedResourceId() {
		let expectedUrl = "http://ranchero.com/blog/atom.xml"
		
		let feedResource = FeedlyFeedResourceId(id: "feed/\(expectedUrl)")
		let urlResource = FeedlyFeedResourceId(id: expectedUrl)
		let otherResource = FeedlyFeedResourceId(id: "whiskey/\(expectedUrl)")
		let invalidResource = FeedlyFeedResourceId(id: "")
		
		XCTAssertEqual(feedResource.url, expectedUrl)
		XCTAssertEqual(urlResource.url, expectedUrl)
		XCTAssertEqual(otherResource.url, otherResource.id)
		XCTAssertEqual(invalidResource.url, invalidResource.id)
	}
}
