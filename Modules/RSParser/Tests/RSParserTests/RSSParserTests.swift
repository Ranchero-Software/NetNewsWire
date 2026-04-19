//
//  RSSParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser

@Suite struct RSSParserTests {

	@Test func natashaTheRobot() throws {
		let d = parserData("natasha", "xml", "https://www.natashatherobot.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count == 10)
	}

	@Test func theOmniShowAttachments() throws {
		let d = parserData("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			let attachments = try #require(article.attachments)
			#expect(attachments.count == 1)
			let attachment = try #require(Array(attachments).first)
			#expect(attachment.mimeType != nil)
			#expect(attachment.sizeInBytes != nil)
			#expect(attachment.url.contains("cloudfront"))
			if let size = attachment.sizeInBytes {
				#expect(size >= 22275279)
			}
			#expect(attachment.mimeType == "audio/mpeg")
		}
	}

	@Test func theOmniShowUniqueIDs() throws {
		let d = parserData("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			#expect(article.uniqueID.hasPrefix("https://theomnishow.omnigroup.com/episode/"))
		}
	}

	@Test func macworldUniqueIDs() throws {
		// Macworld’s feed doesn’t have guids, so they should be calculated unique IDs.

		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			#expect(article.uniqueID.count == 32) // calculated unique IDs are MD5 hashes
		}
	}

	@Test func macworldAuthors() throws {
		// Macworld uses names instead of email addresses (despite the RSS spec saying they should be email addresses).

		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			let author = try #require(article.authors?.first)
			#expect(author.emailAddress == nil)
			#expect(author.url == nil)
			#expect(author.name != nil)
		}
	}

	@Test func monkeyDomGuids() throws {
		// https://coding.monkeydom.de/posts.rss has a bug in the feed (at this writing):
		// It has guids that are supposed to be permalinks, per the spec —
		// except that they’re not actually permalinks. The RSS parser should
		// detect this situation, and every article in the feed should have a permalink.

		let d = parserData("monkeydom", "rss", "https://coding.monkeydom.de/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			#expect(article.url == nil)
		}
	}

	@Test func emptyContentEncoded() throws {
		// The ATP feed (at the time of this writing) has some empty content:encoded elements. The parser should ignore those.
		// https://github.com/brentsimmons/NetNewsWire/issues/529

		let d = parserData("atp", "rss", "http://atp.fm/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		for article in parsedFeed.items {
			#expect(article.contentHTML != nil)
		}
	}

	@Test func feedKnownToHaveGuidsThatArentPermalinks() throws {
		let d = parserData("livemint", "xml", "https://www.livemint.com/rss/news")
		let parsedFeed = try #require(try FeedParser.parse(d))
		for article in parsedFeed.items {
			#expect(article.url == nil)
		}
	}

	@Test func authorsWithTitlesInside() throws {
		// This feed uses atom authors, and we don’t want author/title to be used as item/title.
		// https://github.com/brentsimmons/NetNewsWire/issues/943
		let d = parserData("cloudblog", "rss", "https://cloudblog.withgoogle.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		for article in parsedFeed.items {
			#expect(article.title != "Product Manager, Office of the CTO")
			#expect(article.title != "Developer Programs Engineer")
			#expect(article.title != "Product Director")
		}
	}

	@Test func titlesWithInvalidFeedWithImageStructures() throws {
		// This invalid feed has <image> elements inside <item>s.
		// 17 Jan 2021 bug report — we’re not parsing titles in this feed.
		let d = parserData("aktuality", "rss", "https://www.aktuality.sk/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		for article in parsedFeed.items {
			#expect(article.title != nil)
		}
	}

	@Test func feedLanguage() throws {
		let d = parserData("manton", "rss", "http://manton.org/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.language == "en-US")
	}

	@Test func markdown1() throws {
		let d = parserData("markdown1", "rss", "https://wordland.social/scripting/237777565/rss.xml")
		let parsedFeed = try #require(try FeedParser.parse(d))
		for article in parsedFeed.items {
			#expect(article.markdown != nil)
		}
	}

	@Test func markdown2() throws {
		let d = parserData("markdown2", "rss", "https://wordland.social/scripting/246529703/rss.xml")
		let parsedFeed = try #require(try FeedParser.parse(d))
		for article in parsedFeed.items {
			#expect(article.markdown != nil)
		}
	}

	@Test func feedIconURL() throws {
		let d = parserData("KatieFloyd", "rss", "http://katiefloyd.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.iconURL == "https://static.feedpress.it/logo/katiefloyd.png")
	}

	@Test func feedIconURLNotSetByItemLevelImages() throws {
		// aktuality.rss has <image> elements inside <item>s, not at the channel level.
		// These should not be treated as the feed icon.
		let d = parserData("aktuality", "rss", "https://www.aktuality.sk/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.iconURL == nil)
	}

	@Test func medscapeExternalURLs() throws {
		let d = parserData("medscape", "rss", "https://www.medscape.com/cx/rssfeeds/2674.xml")
		let parsedFeed = try #require(try FeedParser.parse(d))
		for article in parsedFeed.items {
			#expect(article.externalURL != nil)
		}
	}

	@Test func feedWithGB2312Encoding() throws {
		// https://github.com/Ranchero-Software/NetNewsWire/issues/1477
		let d = parserData("kc0011", "rss", "http://kc0011.net/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.items.count > 0)
		for article in parsedFeed.items {
			#expect(article.contentHTML != nil)
		}
	}
}
