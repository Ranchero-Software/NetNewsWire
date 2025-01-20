//
//  AtomParserTests.swift
//  Parser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Parser

final class AtomParserTests: XCTestCase {

	func testDaringFireballPerformance() {

		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "atom", "http://daringfireball.net/") //It’s actually an Atom feed
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testDaringFireball() {

		let d = parserData("DaringFireball", "atom", "http://daringfireball.net/") //It’s actually an Atom feed
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {

			XCTAssertNotNil(article.url)

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

	func testIgnoringBadTitle() {

		// This feed has a title tag inside a thing, like this,
		// and we need to ignore the title.
		// https://github.com/Ranchero-Software/NetNewsWire/issues/4422
		//
		//     <s:variant>
		//     <id>https://draw-down.com/products/8726135046398</id>
		//     		<title>Default Title</title>
		//     		<s:price currency="USD">38.50</s:price>
		//     		<s:sku/>
		//     		<s:grams>862</s:grams>
		//     </s:variant>

		let d = parserData("draw-down", "atom", "https://draw-down.com/collections/magazines.atom")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotEqual(article.title, "Default Title")
		}
	}
}
