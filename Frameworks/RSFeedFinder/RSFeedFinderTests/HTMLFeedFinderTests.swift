//
//  HTMLFeedFinderTests.swift
//  RSFeedFinder
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSFeedFinder
import RSParser

class HTMLFeedFinderTests: XCTestCase {

	func parserData(_ filename: String, _ fileExtension: String, _ url: String) -> ParserData {

		let bundle = Bundle(for: HTMLFeedFinderTests.self)
		let path = bundle.path(forResource: filename, ofType: fileExtension)!
		let data = try! Data(contentsOf: URL(fileURLWithPath: path))
		return ParserData(url: url, data: data)
	}

	func feedFinder(_ fileName: String, _ fileExtension: String, _ url: String) -> HTMLFeedFinder {

		let d = parserData(fileName, fileExtension, url)
		return HTMLFeedFinder(parserData: d)
	}

	func testPerformanceWithDaringFireball() {

		let d = parserData("DaringFireball", "html", "https://daringfireball.net/")
		self.measure {

			let finder = HTMLFeedFinder(parserData: d)
			let _ = finder.feedSpecifiers
		}
	}

	func testHTMLParserWithDaringFireBall() {

		let finder = feedFinder("DaringFireball", "html", "https://daringfireball.net/")
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers)!
		print(bestFeedSpecifier)
	}

//	func testHTMLParserWithFurbo() {
//
//		let finder = HTMLFeedFinder(xmlData: furboData())
//		let feedSpecifiers = finder.feedSpecifiers
//		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
//		print(bestFeedSpecifier)
//	}
//
//	func testHTMLParserWithInessential() {
//
//		let finder = HTMLFeedFinder(xmlData: inessentialData())
//		let feedSpecifiers = finder.feedSpecifiers
//		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
//		print(bestFeedSpecifier)
//	}
//
//	func testHTMLParserWithSixColors() {
//
//		let finder = HTMLFeedFinder(xmlData: sixColorsData())
//		let feedSpecifiers = finder.feedSpecifiers
//		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
//		print(bestFeedSpecifier)
//	}
}



