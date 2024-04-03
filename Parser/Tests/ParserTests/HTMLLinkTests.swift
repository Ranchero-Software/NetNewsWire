//
//  HTMLLinkTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Parser
import ParserObjC

class HTMLLinkTests: XCTestCase {

	func testSixColorsPerformance() {

		// 0.003 sec on my 2012 iMac
		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		self.measure {
			let _ = RSHTMLLinkParser.htmlLinks(with: d)
		}
	}

	func testSixColorsLink() {

		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		let links = RSHTMLLinkParser.htmlLinks(with: d)

		let linkToFind = "https://www.theincomparable.com/theincomparable/290/index.php"
		let textToFind = "this week’s episode of The Incomparable"

		var found = false
		for oneLink in links {
			if let urlString = oneLink.urlString, let text = oneLink.text, urlString == linkToFind, text == textToFind {
				found = true
			}
		}

		XCTAssertTrue(found)
		XCTAssertEqual(links.count, 131)
	}

}
