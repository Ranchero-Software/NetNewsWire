//
//  HTMLLinkPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//
//  Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }`
//  equivalent yet.
//

import XCTest
import RSParser
import RSParserObjC

final class HTMLLinkPerformanceTests: XCTestCase {

	func testSixColorsPerformance() {
		// 0.003 sec on my 2012 iMac
		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		self.measure {
			_ = RSHTMLLinkParser.htmlLinks(with: d)
		}
	}
}
