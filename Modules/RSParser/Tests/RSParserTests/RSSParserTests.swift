//
//  RSSParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

final class RSSParserTests: XCTestCase {

	func testScriptingNewsPerformance() {

		// 0.004 sec on my 2012 iMac.
		let d = parserData("scriptingNews", "rss", "http://scripting.com/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testKatieFloydPerformance() {

		// 0.004 sec on my 2012 iMac.
		let d = parserData("KatieFloyd", "rss", "http://katiefloyd.com/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testEMarleyPerformance() {

		// 0.001 sec on my 2012 iMac.
		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testMantonPerformance() {

		// 0.002 sec on my 2012 iMac.
		let d = parserData("manton", "rss", "http://manton.org/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testNatashaTheRobot() {

		let d = parserData("natasha", "xml", "https://www.natashatherobot.com/")
		let parsedFeed = try! FeedParser.parse(d)!
		XCTAssertEqual(parsedFeed.items.count, 10)
	}

	func testTheOmniShowAttachments() {

		let d = parserData("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.attachments)
			XCTAssertEqual(article.attachments!.count, 1)
			let attachment = Array(article.attachments!).first!
			XCTAssertNotNil(attachment.mimeType)
			XCTAssertNotNil(attachment.sizeInBytes)
			XCTAssert(attachment.url.contains("cloudfront"))
			XCTAssertGreaterThanOrEqual(attachment.sizeInBytes!, 22275279)
			XCTAssertEqual(attachment.mimeType, "audio/mpeg")
		}
	}

	func testTheOmniShowUniqueIDs() {

		let d = parserData("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.uniqueID)
			XCTAssertTrue(article.uniqueID.hasPrefix("https://theomnishow.omnigroup.com/episode/"))
		}
	}

	func testMacworldUniqueIDs() {

		// Macworld’s feed doesn’t have guids, so they should be calculated unique IDs.

		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.uniqueID)
			XCTAssertEqual(article.uniqueID.count, 32) // calculated unique IDs are MD5 hashes
		}
	}

	func testMacworldAuthors() {

		// Macworld uses names instead of email addresses (despite the RSS spec saying they should be email addresses).

		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {

			let author = article.authors!.first!
			XCTAssertNil(author.emailAddress)
			XCTAssertNil(author.url)
			XCTAssertNotNil(author.name)
		}
	}

	func testMonkeyDomGuids() {

		// https://coding.monkeydom.de/posts.rss has a bug in the feed (at this writing):
		// It has guids that are supposed to be permalinks, per the spec —
		// except that they’re not actually permalinks. The RSS parser should
		// detect this situation, and every article in the feed should have a permalink.

		let d = parserData("monkeydom", "rss", "https://coding.monkeydom.de/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNil(article.url)
			XCTAssertNotNil(article.uniqueID)
		}
	}

	func testEmptyContentEncoded() {
		// The ATP feed (at the time of this writing) has some empty content:encoded elements. The parser should ignore those.
		// https://github.com/brentsimmons/NetNewsWire/issues/529

		let d = parserData("atp", "rss", "http://atp.fm/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.contentHTML)
		}
	}

	func testFeedKnownToHaveGuidsThatArentPermalinks() {
		let d = parserData("livemint", "xml", "https://www.livemint.com/rss/news")
		let parsedFeed = try! FeedParser.parse(d)!
		for article in parsedFeed.items {
			XCTAssertNil(article.url)
		}
	}

	func testAuthorsWithTitlesInside() {
		// This feed uses atom authors, and we don’t want author/title to be used as item/title.
		// https://github.com/brentsimmons/NetNewsWire/issues/943
		let d = parserData("cloudblog", "rss", "https://cloudblog.withgoogle.com/")
		let parsedFeed = try! FeedParser.parse(d)!
		for article in parsedFeed.items {
			XCTAssertNotEqual(article.title, "Product Manager, Office of the CTO")
			XCTAssertNotEqual(article.title, "Developer Programs Engineer")
			XCTAssertNotEqual(article.title, "Product Director")
		}
	}

    func testTitlesWithInvalidFeedWithImageStructures() {
        // This invalid feed has <image> elements inside <item>s.
        // 17 Jan 2021 bug report — we’re not parsing titles in this feed.
        let d = parserData("aktuality", "rss", "https://www.aktuality.sk/")
        let parsedFeed = try! FeedParser.parse(d)!
        for article in parsedFeed.items {
            XCTAssertNotNil(article.title)
        }
    }

	func testFeedLanguage() {
		let d = parserData("manton", "rss", "http://manton.org/")
		let parsedFeed = try! FeedParser.parse(d)!
		XCTAssertEqual(parsedFeed.language, "en-US")
	}

	func testMarkdown1() {
		let d = parserData("markdown1", "rss", "https://wordland.social/scripting/237777565/rss.xml")
		let parsedFeed = try! FeedParser.parse(d)!
		for article in parsedFeed.items {
			XCTAssertNotNil(article.markdown)
		}
	}

	func testMarkdown2() {
		let d = parserData("markdown2", "rss", "https://wordland.social/scripting/246529703/rss.xml")
		let parsedFeed = try! FeedParser.parse(d)!
		for article in parsedFeed.items {
			XCTAssertNotNil(article.markdown)
		}
	}

//	func testFeedWithGB2312Encoding() {
//		// This feed has an encoding we don’t run into very often.
//		// https://github.com/Ranchero-Software/NetNewsWire/issues/1477
//		let d = parserData("kc0011", "rss", "http://kc0011.net/")
//		let parsedFeed = try! FeedParser.parse(d)!
//		XCTAssert(parsedFeed.items.count > 0)
//		for article in parsedFeed.items {
//			XCTAssertNotNil(article.contentHTML)
//		}
//	}
}
