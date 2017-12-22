//
//  AtomParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class AtomParserTests: XCTestCase {

	func testDaringFireballPerformance() {

		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "atom", "http://daringfireball.net/") //It’s actually an Atom feed
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testAllThisPerformance() {

		// 0.003 sec on my 2012 iMac.
		let d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testGettingHomePageLink() {

		let d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		let parsedFeed = try! FeedParser.parse(d)!

		XCTAssertTrue(parsedFeed.homePageURL == "http://leancrew.com/all-this")
	}

	func testDaringFireball() {

		let d = parserData("DaringFireball", "atom", "http://daringfireball.net/") //It’s actually an Atom feed
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {

			XCTAssertNotNil(article.externalURL)

			if !article.title!.hasPrefix("★ ") {
				XCTAssertNotNil(article.url)
				XCTAssert(article.url!.hasPrefix("https://daringfireball.net/"))
			}

			XCTAssertTrue(article.uniqueID.hasPrefix("tag:daringfireball.net,2017:/"))

			XCTAssertEqual(article.authors!.count, 1) // TODO: parse Atom authors
			let author = article.authors!.first!
			if author.name == "Daring Fireball Department of Commerce" {
				XCTAssertNil(author.url)
			}
			else {
				XCTAssertEqual(author.name, "John Gruber")
				XCTAssertEqual(author.url, "http://daringfireball.net/")
			}

			XCTAssertNotNil(article.datePublished)
			XCTAssert(article.attachments == nil)
		}
	}

	func test4fsodonlineAttachments() {

		// Thanks to Marco for finding me some Atom podcast feeds. Apparently they’re super-rare.

		let d = parserData("4fsodonline", "atom", "http://4fsodonline.blogspot.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {

			XCTAssertTrue(article.attachments!.count > 0)
			let attachment = article.attachments!.first!

			XCTAssertTrue(attachment.url.hasPrefix("http://www.blogger.com/video-play.mp4?"))
			XCTAssertNil(attachment.sizeInBytes)
			XCTAssertEqual(attachment.mimeType!, "video/mp4")
		}
	}

	func testExpertOpinionENTAttachments() {

		// Another from Marco.

		let d = parserData("expertopinionent", "atom", "http://expertopinionent.typepad.com/my-blog/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {

			guard let attachments = article.attachments else {
				continue
			}
			
			XCTAssertEqual(attachments.count, 1)
			let attachment = attachments.first!

			XCTAssertTrue(attachment.url.hasSuffix(".mp3"))
			XCTAssertNil(attachment.sizeInBytes)
			XCTAssertEqual(attachment.mimeType!, "audio/mpeg")
		}
	}
}
