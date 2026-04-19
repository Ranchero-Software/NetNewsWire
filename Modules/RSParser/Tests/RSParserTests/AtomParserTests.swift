//
//  AtomParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser

@Suite struct AtomParserTests {

	@Test func gettingHomePageLink() throws {
		let cases: [(file: String, feedURL: String, expectedHomePage: String)] = [
			("allthis", "http://leancrew.com/all-this", "http://leancrew.com/all-this"),
			("qemu", "https://www.qemu.org/feed.xml", "https://www.qemu.org/"),
			("yakubin", "https://yakubin.com/notes/atom.xml", "https://yakubin.com/notes"),
			("4fsodonline", "http://4fsodonline.blogspot.com/feeds/posts/default", "http://4fsodonline.blogspot.com/"),
			("DaringFireball", "https://daringfireball.net/feeds/main", "https://daringfireball.net/"),
			("neverworkintheory", "https://neverworkintheory.org/atom.xml", "https://neverworkintheory.org/")
		]

		for c in cases {
			let d = parserData(c.file, "atom", c.feedURL)
			let parsedFeed = try #require(try FeedParser.parse(d))
			#expect(parsedFeed.homePageURL == c.expectedHomePage, "homePageURL mismatch for \(c.file)")
		}
	}

	@Test func articlePermalinks() throws {
		var d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		var parsedFeed = try #require(try FeedParser.parse(d))

		var foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "QEMU version 10.1.0 released" {
				foundTestArticle = true
				#expect(item.url == "https://www.qemu.org/2025/08/26/qemu-10-1-0/")
			}
		}
		#expect(foundTestArticle)

		d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		parsedFeed = try #require(try FeedParser.parse(d))

		foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "Virgin Mobile Partners With Apple to Go iPhone-Only With $1 Service" {
				foundTestArticle = true
				#expect(item.url == "https://daringfireball.net/linked/2017/06/26/virgin-mobile-iphone-only")
			}
		}
		#expect(foundTestArticle)

		d = parserData("neverworkintheory", "atom", "https://neverworkintheory.org/atom.xml")
		parsedFeed = try #require(try FeedParser.parse(d))

		foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "Andreas Zeller on Creating Nasty Test Inputs" {
				foundTestArticle = true
				#expect(item.url == "https://neverworkintheory.org/2023/06/13/zeller-andreas.html")
			}
		}
		#expect(foundTestArticle)
	}

	@Test func articleExternalLinks() throws {
		var d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		var parsedFeed = try #require(try FeedParser.parse(d))

		var foundTestArticle = false
		for item in parsedFeed.items {
			if item.title == "Kara Swisher: ‘Susan Fowler Proved That One Person Can Make a Difference’" {
				foundTestArticle = true
				#expect(item.externalURL == "https://www.recode.net/2017/6/21/15844852/uber-toxic-bro-company-culture-susan-fowler-blog-post")
			}
		}
		#expect(foundTestArticle)

		d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		parsedFeed = try #require(try FeedParser.parse(d))

		#expect(parsedFeed.items.count > 0)
		for item in parsedFeed.items {
			#expect(item.externalURL == nil)
		}
	}

	@Test func daringFireball() throws {
		let d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			#expect(article.url != nil)
			#expect(article.uniqueID.hasPrefix("tag:daringfireball.net,2017:/"))

			let authors = try #require(article.authors)
			#expect(authors.count == 1) // TODO: parse Atom authors
			let author = try #require(authors.first)
			if author.name == "Daring Fireball Department of Commerce" {
				#expect(author.url == nil)
			} else {
				#expect(author.name == "John Gruber")
				#expect(author.url == "http://daringfireball.net/")
			}

			#expect(article.datePublished != nil)
			#expect(article.attachments == nil)
			#expect(article.language == "en")
		}
	}

	@Test func fsodonlineAttachments() throws {
		// Thanks to Marco for finding me some Atom podcast feeds. Apparently they’re super-rare.

		let d = parserData("4fsodonline", "atom", "http://4fsodonline.blogspot.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			let attachments = try #require(article.attachments)
			#expect(attachments.count > 0)
			let attachment = try #require(attachments.first)

			#expect(attachment.url.hasPrefix("http://www.blogger.com/video-play.mp4?"))
			#expect(attachment.sizeInBytes == nil)
			#expect(attachment.mimeType == "video/mp4")
		}
	}

	@Test func expertOpinionENTAttachments() throws {
		// Another from Marco.

		let d = parserData("expertopinionent", "atom", "http://expertopinionent.typepad.com/my-blog/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			guard let attachments = article.attachments else {
				continue
			}

			#expect(attachments.count == 1)
			let attachment = try #require(attachments.first)

			#expect(attachment.url.hasSuffix(".mp3"))
			#expect(attachment.sizeInBytes == nil)
			#expect(attachment.mimeType == "audio/mpeg")
		}
	}

	@Test func feedIconURL() throws {
		let d = parserData("root-author", "atom", "https://fvsch.com/feed.xml")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.iconURL == "https://fvsch.com/assets/images/icon.png?v=ql0r5y")
	}

	@Test func authorAtRoot() throws {
		let d = parserData("root-author", "atom", "https://fvsch.com/feed.xml")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			let author = article.authors?.first
			#expect(author != nil)

			#expect(author?.name == "Florens Verschelde")
			#expect(author?.url == nil)
			#expect(author?.avatarURL == nil)
			#expect(author?.emailAddress == nil)
		}
	}
}
