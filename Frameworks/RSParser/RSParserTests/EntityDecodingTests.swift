//
//  EntityDecodingTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 12/30/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class EntityDecodingTests: XCTestCase {

    func test39Decoding() {

		// Bug found by Manton Reece — the &#39; entity was not getting decoded by Evergreen in JSON Feeds from micro.blog.

		let s = "These are the times that try men&#39;s souls."
		let decoded = s.rsparser_stringByDecodingHTMLEntities()

		XCTAssertEqual(decoded, "These are the times that try men's souls.")
	}
}
