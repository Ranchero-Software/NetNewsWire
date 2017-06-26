//
//  HTMLMetadataTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class HTMLMetadataTests: XCTestCase {

	func testDaringFireball() {

		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		XCTAssertEqual(metadata.faviconLink, "http://daringfireball.net/graphics/favicon.ico?v=005")

		XCTAssertEqual(metadata.feedLinks.count, 1)

		let feedLink = metadata.feedLinks.first!
		XCTAssertNil(feedLink.title)
		XCTAssertEqual(feedLink.type, "application/atom+xml")
		XCTAssertEqual(feedLink.urlString, "http://daringfireball.net/feeds/main")
	}

	func testDaringFireballPerformance() {

		// 0.002 sec on my 2012 iMac
		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		self.measure {
			let _ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testFurbo() {

		let d = parserData("furbo", "html", "http://furbo.org/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		XCTAssertEqual(metadata.faviconLink, "http://furbo.org/favicon.ico")

		XCTAssertEqual(metadata.feedLinks.count, 1)

		let feedLink = metadata.feedLinks.first!
		XCTAssertEqual(feedLink.title, "Iconfactory News Feed")
		XCTAssertEqual(feedLink.type, "application/rss+xml")
	}

	func testFurboPerformance() {

		// 0.001 sec on my 2012 iMac
		let d = parserData("furbo", "html", "http://furbo.org/")
		self.measure {
			let _ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testInessential() {

		let d = parserData("inessential", "html", "http://inessential.com/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		XCTAssertNil(metadata.faviconLink)

		XCTAssertEqual(metadata.feedLinks.count, 1)
		let feedLink = metadata.feedLinks.first!
		XCTAssertEqual(feedLink.title, "RSS")
		XCTAssertEqual(feedLink.type, "application/rss+xml")
		XCTAssertEqual(feedLink.urlString, "http://inessential.com/xml/rss.xml")

		XCTAssertEqual(metadata.appleTouchIcons.count, 0);
	}

	func testInessentialPerformance() {

		// 0.001 sec on my 2012 iMac
		let d = parserData("inessential", "html", "http://inessential.com/")
		self.measure {
			let _ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testSixColors() {

		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		XCTAssertEqual(metadata.faviconLink, "https://sixcolors.com/images/favicon.ico")

		XCTAssertEqual(metadata.feedLinks.count, 1);
		let feedLink = metadata.feedLinks.first!
		XCTAssertEqual(feedLink.title, "RSS");
		XCTAssertEqual(feedLink.type, "application/rss+xml");
		XCTAssertEqual(feedLink.urlString, "http://feedpress.me/sixcolors");

		XCTAssertEqual(metadata.appleTouchIcons.count, 6);
		let icon = metadata.appleTouchIcons[3];
		XCTAssertEqual(icon.rel, "apple-touch-icon");
		XCTAssertEqual(icon.sizes, "120x120");
		XCTAssertEqual(icon.urlString, "https://sixcolors.com/apple-touch-icon-120.png");
	}

	func testSixColorsPerformance() {

		// 0.002 sec on my 2012 iMac
		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		self.measure {
			let _ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}
}
