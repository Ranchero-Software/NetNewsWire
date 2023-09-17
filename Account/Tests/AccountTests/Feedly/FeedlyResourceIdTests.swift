//
//  FeedlyResourceIDTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class FeedlyResourceIDTests: XCTestCase {
	
	func testFeedResourceID() {
		let expectedURL = "http://ranchero.com/blog/atom.xml"
		
		let feedResource = FeedlyFeedResourceID(id: "feed/\(expectedURL)")
		let urlResource = FeedlyFeedResourceID(id: expectedURL)
		let otherResource = FeedlyFeedResourceID(id: "whiskey/\(expectedURL)")
		let invalidResource = FeedlyFeedResourceID(id: "")
		
		XCTAssertEqual(feedResource.url, expectedURL)
		XCTAssertEqual(urlResource.url, expectedURL)
		XCTAssertEqual(otherResource.url, otherResource.id)
		XCTAssertEqual(invalidResource.url, invalidResource.id)
	}
}
