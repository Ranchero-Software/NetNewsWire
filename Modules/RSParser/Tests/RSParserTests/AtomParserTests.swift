//
//  AtomParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

final class AtomParserTests: XCTestCase {

	func testDaringFireballPerformance() {

		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testAllThisPerformance() {

		// 0.003 sec on my 2012 iMac.
		let d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testGettingHomePageLink() {

		var d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		var parsedFeed = try! FeedParser.parse(d)!
		XCTAssertTrue(parsedFeed.homePageURL == "http://leancrew.com/all-this")

		d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		parsedFeed = try! FeedParser.parse(d)!
		XCTAssertTrue(parsedFeed.homePageURL == "https://www.qemu.org/")

		d = parserData("yakubin", "atom", "https://yakubin.com/notes/atom.xml")
		parsedFeed = try! FeedParser.parse(d)!
		XCTAssertTrue(parsedFeed.homePageURL == "https://yakubin.com/notes")

		d = parserData("4fsodonline", "atom", "http://4fsodonline.blogspot.com/feeds/posts/default")
		parsedFeed = try! FeedParser.parse(d)!
		XCTAssertTrue(parsedFeed.homePageURL == "http://4fsodonline.blogspot.com/")

		d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		parsedFeed = try! FeedParser.parse(d)!
		XCTAssertTrue(parsedFeed.homePageURL == "https://daringfireball.net/")

		d = parserData("neverworkintheory", "atom", "https://neverworkintheory.org/atom.xml")
		parsedFeed = try! FeedParser.parse(d)!
		XCTAssertTrue(parsedFeed.homePageURL == "https://neverworkintheory.org/")
	}

	func testArticlePermalinks() {

		var d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		var parsedFeed = try! FeedParser.parse(d)!

		var foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "QEMU version 10.1.0 released" {
				foundTestArticle = true
				XCTAssertEqual(item.url, "https://www.qemu.org/2025/08/26/qemu-10-1-0/")
			}
		}
		XCTAssertTrue(foundTestArticle)

		d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		parsedFeed = try! FeedParser.parse(d)!

		foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "Virgin Mobile Partners With Apple to Go iPhone-Only With $1 Service" {
				foundTestArticle = true
				XCTAssertEqual(item.url, "https://daringfireball.net/linked/2017/06/26/virgin-mobile-iphone-only")
			}
		}
		XCTAssertTrue(foundTestArticle)

		d = parserData("neverworkintheory", "atom", "https://neverworkintheory.org/atom.xml")
		parsedFeed = try! FeedParser.parse(d)!

		foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "Andreas Zeller on Creating Nasty Test Inputs" {
				foundTestArticle = true
				XCTAssertEqual(item.url, "https://neverworkintheory.org/2023/06/13/zeller-andreas.html")
			}
		}
		XCTAssertTrue(foundTestArticle)

	}

	func testArticleExternalLinks() {

		var d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		var parsedFeed = try! FeedParser.parse(d)!

		var foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "Kara Swisher: ‘Susan Fowler Proved That One Person Can Make a Difference’" {
				foundTestArticle = true
				XCTAssertEqual(item.externalURL, "https://www.recode.net/2017/6/21/15844852/uber-toxic-bro-company-culture-susan-fowler-blog-post")
			}
		}
		XCTAssertTrue(foundTestArticle)

		d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		parsedFeed = try! FeedParser.parse(d)!

		XCTAssert(parsedFeed.items.count > 0)
		for item in parsedFeed.items {
			XCTAssertNil(item.externalURL)
		}
	}

	func testDaringFireball() {

		let d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {

			XCTAssertNotNil(article.url)

			XCTAssertTrue(article.uniqueID.hasPrefix("tag:daringfireball.net,2017:/"))

			XCTAssertEqual(article.authors!.count, 1) // TODO: parse Atom authors
			let author = article.authors!.first!
			if author.name == "Daring Fireball Department of Commerce" {
				XCTAssertNil(author.url)
			} else {
				XCTAssertEqual(author.name, "John Gruber")
				XCTAssertEqual(author.url, "http://daringfireball.net/")
			}

			XCTAssertNotNil(article.datePublished)
			XCTAssert(article.attachments == nil)

			XCTAssertEqual(article.language, "en")
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

	func testAuthorAtRoot() {
		let d = parserData("root-author", "atom", "https://fvsch.com/feed.xml")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			let author = article.authors?.first
			XCTAssertNotNil(author)

			XCTAssertEqual(author?.name, "Florens Verschelde")

			XCTAssertNil(author?.url)
			XCTAssertNil(author?.avatarURL)
			XCTAssertNil(author?.emailAddress)
		}
	}
}
