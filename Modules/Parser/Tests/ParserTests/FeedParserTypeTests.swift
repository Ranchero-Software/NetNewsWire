//
//  FeedParserTypeTests.swift
//  Parser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Parser

final class FeedParserTypeTests: XCTestCase {

	// MARK: HTML

	func testDaringFireballHTMLType() {

		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .notAFeed)
	}

	func testFurboHTMLType() {

		let d = parserData("furbo", "html", "http://furbo.org/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .notAFeed)
	}

	func testInessentialHTMLType() {

		let d = parserData("inessential", "html", "http://inessential.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .notAFeed)
	}

	func testSixColorsHTMLType() {

		let d = parserData("sixcolors", "html", "https://sixcolors.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .notAFeed)
	}

	// MARK: RSS

	func testEMarleyRSSType() {

		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testScriptingNewsRSSType() {

		let d = parserData("scriptingNews", "rss", "http://scripting.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testKatieFloydRSSType() {

		let d = parserData("KatieFloyd", "rss", "https://katiefloyd.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testMantonRSSType() {

		let d = parserData("manton", "rss", "http://manton.org/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testDCRainmakerRSSType() {

		let d = parserData("dcrainmaker", "xml", "https://www.dcrainmaker.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testMacworldRSSType() {

		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testNatashaTheRobotRSSType() {

		let d = parserData("natasha", "xml", "https://www.natashatherobot.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testDontHitSaveRSSWithBOMType() {

		let d = parserData("donthitsave", "xml", "http://donthitsave.com/donthitsavefeed.xml")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testBioRDF() {
		let d = parserData("bio", "rdf", "http://connect.biorxiv.org/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	func testPHPXML() {
		let d = parserData("phpxml", "rss", "https://www.fcutrecht.net/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rss)
	}

	// MARK: Atom

	func testDaringFireballAtomType() {

		// File extension is .rss, but it’s really an Atom feed.
		let d = parserData("DaringFireball", "rss", "http://daringfireball.net/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .atom)
	}

	func testOneFootTsunamiAtomType() {

		let d = parserData("OneFootTsunami", "atom", "http://onefoottsunami.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .atom)
	}

	func testRussCoxAtomType() {
		let d = parserData("russcox", "atom", "https://research.swtch.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .atom)
	}

	// MARK: RSS-in-JSON

	func testScriptingNewsJSONType() {

		let d = parserData("ScriptingNews", "json", "http://scripting.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .rssInJSON)
	}

	// MARK: JSON Feed

	func testInessentialJSONFeedType() {

		let d = parserData("inessential", "json", "http://inessential.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .jsonFeed)
	}

	func testAllThisJSONFeedType() {

		let d = parserData("allthis", "json", "http://leancrew.com/allthis/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .jsonFeed)
	}

	func testCurtJSONFeedType() {

		let d = parserData("curt", "json", "http://curtclifton.net/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .jsonFeed)
	}

	func testPixelEnvyJSONFeedType() {

		let d = parserData("pxlnv", "json", "http://pxlnv.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .jsonFeed)
	}

	func testRoseJSONFeedType() {

		let d = parserData("rose", "json", "https://www.rosemaryorchard.com/")
		let type = FeedType.feedType(d.data)
		XCTAssertTrue(type == .jsonFeed)
	}

	// MARK: Unknown

	func testPartialAllThisUnknownFeedType() {

		// In the case of this feed, the partial data isn’t enough to detect that it’s a JSON Feed.
		// The type detector should return .unknown rather than .notAFeed.

		let d = parserData("allthis-partial", "json", "http://leancrew.com/allthis/")
		let type = FeedType.feedType(d.data, isPartialData: true)
		XCTAssertEqual(type, .unknown)
	}

	// MARK: Performance

	func testFeedTypePerformance() {

		// 0.000 on my 2012 iMac.

		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		self.measure {
			_ = FeedType.feedType(d.data)
		}
	}

	func testFeedTypePerformance2() {

		// 0.000 on my 2012 iMac.

		let d = parserData("inessential", "json", "http://inessential.com/")
		self.measure {
			_ = FeedType.feedType(d.data)
		}
	}

	func testFeedTypePerformance3() {

		// 0.000 on my 2012 iMac.

		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		self.measure {
			_ = FeedType.feedType(d.data)
		}
	}

	func testFeedTypePerformance4() {

		// 0.001 on my 2012 iMac.

		let d = parserData("DaringFireball", "rss", "http://daringfireball.net/")
		self.measure {
			_ = FeedType.feedType(d.data)
		}
	}
}
