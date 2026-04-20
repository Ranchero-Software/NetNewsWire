//
//  JSONFeedParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser

@Suite struct JSONFeedParserTests {

	@Test func gettingFaviconAndIconURLs() throws {
		let d = parserData("DaringFireball", "json", "http://daringfireball.net/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		#expect(parsedFeed.faviconURL == "https://daringfireball.net/graphics/favicon-64.png")
		#expect(parsedFeed.iconURL == "https://daringfireball.net/graphics/apple-touch-icon.png")
	}

	@Test func allThis() throws {
		let d = parserData("allthis", "json", "http://leancrew.com/allthis/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count == 12)
	}

	@Test func curt() throws {
		let d = parserData("curt", "json", "http://curtclifton.net/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		#expect(parsedFeed.items.count == 26)

		var didFindTwitterQuitterArticle = false
		for article in parsedFeed.items {
			if article.title == "Twitter Quitter" {
				didFindTwitterQuitterArticle = true
				#expect(article.contentHTML?.hasPrefix("<p>I&#8217;ve decided to close my Twitter account. William Van Hecke <a href=\"https://tinyletter.com/fet/letters/microcosmographia-xlxi-reasons-to-stay-on-twitter\">makes a convincing case</a>") == true)
			}
		}

		#expect(didFindTwitterQuitterArticle)
	}

	@Test func pixelEnvy() throws {
		let d = parserData("pxlnv", "json", "http://pxlnv.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count == 20)
	}

	@Test func rose() throws {
		let d = parserData("rose", "json", "http://www.rosemaryorchard.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count == 84)
	}

	@Test func threeNineSixZero() throws {
		let d = parserData("3960", "json", "http://journal.3960.org/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count == 20)
		#expect(parsedFeed.language == "de-DE")

		for item in parsedFeed.items {
			#expect(item.language == "de-DE")
		}
	}

	@Test func authors() throws {
		let d = parserData("authors", "json", "https://example.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count == 4)

		let rootAuthors = Set([
			ParsedAuthor(name: "Root Author 1", url: nil, avatarURL: nil, emailAddress: nil),
			ParsedAuthor(name: "Root Author 2", url: nil, avatarURL: nil, emailAddress: nil)
		])
		let itemAuthors = Set([
			ParsedAuthor(name: "Item Author 1", url: nil, avatarURL: nil, emailAddress: nil),
			ParsedAuthor(name: "Item Author 2", url: nil, avatarURL: nil, emailAddress: nil)
		])
		let legacyItemAuthors = Set([
			ParsedAuthor(name: "Legacy Item Author", url: nil, avatarURL: nil, emailAddress: nil)
		])

		#expect(parsedFeed.authors?.count == 2)
		#expect(parsedFeed.authors == rootAuthors)

		let noAuthorsItem = try #require(parsedFeed.items.first { $0.uniqueID == "Item without authors" })
		#expect(noAuthorsItem.authors == nil)

		let legacyAuthorItem = try #require(parsedFeed.items.first { $0.uniqueID == "Item with legacy author" })
		#expect(legacyAuthorItem.authors == legacyItemAuthors)

		let modernAuthorsItem = try #require(parsedFeed.items.first { $0.uniqueID == "Item with modern authors" })
		#expect(modernAuthorsItem.authors == itemAuthors)

		let bothAuthorsItem = try #require(parsedFeed.items.first { $0.uniqueID == "Item with both" })
		#expect(bothAuthorsItem.authors == itemAuthors)
	}
}
