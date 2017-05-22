//
//  HTMLFeedFinderTests.swift
//  RSFeedFinder
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

import XCTest
@testable import RSFeedFinder
import RSXML

class HTMLFeedFinderTests: XCTestCase {

	private var xmlDataCache = [String: RSXMLData]()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

	func xmlDataFor(title: String, urlString: String) -> RSXMLData? {

		if let cachedXMLData = xmlDataCache[title] {
			return cachedXMLData
		}

		if let s = Bundle(for: self.dynamicType).url(forResource: title, withExtension: "html") {
			let d = try! Data(contentsOf: s)
			let xmlData = RSXMLData(data: d, urlString: urlString)
			xmlDataCache[title] = xmlData
			return xmlData
		}
		return nil
	}

	func daringFireballData() -> RSXMLData {

		return xmlDataFor(title:"DaringFireball", urlString:"http://daringfireball.net/")!
	}

	func furboData() -> RSXMLData {

		return xmlDataFor(title:"furbo", urlString:"http://furbo.org/")!
	}

	func inessentialData() -> RSXMLData {

		return xmlDataFor(title:"inessential", urlString:"http://inessential.com/")!
	}

	func sixColorsData() -> RSXMLData {

		return xmlDataFor(title:"sixcolors", urlString:"https://sixcolors.com/")!
	}

	func testPerformanceWithDaringFireball() {

		let xmlData = daringFireballData()
		self.measure {

			let finder = HTMLFeedFinder(xmlData: xmlData)
			let _ = finder.feedSpecifiers
		}
	}

	func testHTMLParserWithDaringFireBall() {

		let finder = HTMLFeedFinder(xmlData: daringFireballData())
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
		print(bestFeedSpecifier)
	}

	func testHTMLParserWithFurbo() {

		let finder = HTMLFeedFinder(xmlData: furboData())
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
		print(bestFeedSpecifier)
	}

	func testHTMLParserWithInessential() {

		let finder = HTMLFeedFinder(xmlData: inessentialData())
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
		print(bestFeedSpecifier)
	}

	func testHTMLParserWithSixColors() {

		let finder = HTMLFeedFinder(xmlData: sixColorsData())
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedFinder.bestFeed(in: feedSpecifiers)
		print(bestFeedSpecifier)
	}
}
