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

	// MARK: - Entity decoding regression

	// These pin down the behavior we intentionally made libxml2-compatible in the
	// pure-Swift port: inside CDATA no entity substitution at all, and in text
	// content HTML named entities (`&nbsp;`, `&mdash;`, etc.) pass through literally
	// — only predefined XML entities and numeric entities are expanded.

	@Test func cdataBodyPreservesHTMLNamedEntities() throws {
		// KatieFloyd's bodies are CDATA-wrapped and contain `&nbsp;` — the parsed
		// contentHTML must keep that literal, not decode it to U+00A0. A future change
		// that turned on entity decoding inside CDATA would break this.
		let d = parserData("KatieFloyd", "rss", "http://katiefloyd.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		let bodyWithNbsp = parsedFeed.items.first { $0.contentHTML?.contains("&nbsp;") == true }
		#expect(bodyWithNbsp != nil, "Expected at least one KatieFloyd item to contain literal &nbsp; in contentHTML")

		for item in parsedFeed.items {
			if let html = item.contentHTML {
				// The non-breaking space (U+00A0) must NOT appear in these CDATA bodies —
				// only its literal `&nbsp;` spelling.
				#expect(!html.contains("\u{00A0}"), "unexpected decoded nbsp in contentHTML")
			}
		}
	}

	@Test func cdataBodyPreservesNumericEntities() throws {
		// DaringFireball RSS bodies are CDATA-wrapped and use `&#8217;` (right-single-quote).
		// CDATA is raw, so the entity must pass through literally.
		let d = parserData("DaringFireball", "rss", "http://daringfireball.net/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		let bodyWithNumericEntity = parsedFeed.items.first { $0.contentHTML?.contains("&#8217;") == true }
		#expect(bodyWithNumericEntity != nil, "Expected at least one DaringFireball item to contain literal &#8217; in contentHTML")
	}

	// MARK: - Encoding regression

	@Test func gb2312FeedDecodesChineseCorrectly() throws {
		// kc0011 declares `encoding="gb2312"`; real-world such files are usually GBK.
		// Verify the Chinese title round-trips to UTF-8 correctly — a regression that
		// treated it as strict GB 2312-80 (or as Latin-1) would produce garbled output.
		let d = parserData("kc0011", "rss", "http://kc0011.net/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.title == "投资资讯网交易在线--流通纪念币最新20篇论坛主题-全文")
	}

	@Test func cjkItemTitlesPreserveMultiByteUTF8() throws {
		// Once the bytes are transcoded to UTF-8 at the stream level, the
		// element-text path must preserve all multi-byte sequences verbatim
		// through the character-accumulator → trim → materialize pipeline.
		// A regression that sliced by byte count anywhere would corrupt CJK.
		let d = parserData("kc0011", "rss", "http://kc0011.net/")
		let feed = try #require(try FeedParser.parse(d))
		// Every item title should contain Chinese characters (codepoints > 127).
		var sawChinese = false
		for item in feed.items {
			guard let title = item.title else {
				continue
			}
			if title.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF }) {
				sawChinese = true
			}
			// No stray replacement characters (indicates decoding failure).
			#expect(!title.contains("\u{FFFD}"), "replacement character in title: \(title)")
		}
		#expect(sawChinese, "expected at least one kc0011 item title with CJK Unified Ideographs")
	}

	// MARK: - RSS 1.0 (RDF) regression

	@Test func rdfFeedParsesAsRSS() throws {
		// bio.rdf is RSS 1.0 (RDF/XML). The parser recognizes `<rdf:RDF>` as the
		// root and uses each `<item>`'s `rdf:about` attribute as its uniqueID and
		// permalink — that's what the old ObjC parser did, and the app relies on
		// it to keep stable uniqueIDs across syncs. An earlier `isUnprefixed`
		// guard in the Swift port silently broke this (items got calculated MD5
		// uniqueIDs and nil URLs); this test pins that regression shut.
		let d = parserData("bio", "rdf", "http://biorxiv.org/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		#expect(parsedFeed.title == "bioRxiv Subject Collection: Plant Biology")
		#expect(parsedFeed.homePageURL == "http://biorxiv.org")
		#expect(parsedFeed.items.count == 30)

		for item in parsedFeed.items {
			#expect(item.title != nil, "RDF item missing title")
			#expect(item.url != nil, "RDF item missing URL — rdf:about not consumed?")
			#expect(item.uniqueID.hasPrefix("http://biorxiv.org/cgi/content/"))
		}
	}

	// MARK: - Date parser regression

	// MARK: - Byte-stability pinning (protects iCloud sync + DB row stability)

	// These tests pin specific output byte-for-byte. Once the ObjC parsers are
	// gone we can't re-derive "the right answer" by comparison, so the contract
	// has to be captured here. A regression that silently reshuffled these
	// values would turn every existing article into a "new" article on next
	// parse — blowing up the article database, the FTS index, and iCloud sync.

	@Test func macworldCalculatedUniqueIDsArePinnedMD5s() throws {
		// Macworld's feed has no `<guid>`, so uniqueIDs are deterministic MD5
		// hashes of (title + author + pubDate + contentHTML). Pin specific
		// hashes for specific titles to catch any change in that pipeline —
		// whitespace handling, entity decoding, date serialization, etc.
		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let feed = try #require(try FeedParser.parse(d))
		let expected: [String: String] = [
			"Black Friday Exclusive: Save Over 40% On The Nix Mini Color Sensor - Deal Alert":
				"7ee68b71282bbf0f9a203f5c362e048a",
			"The iMac Pro might be the first ARM Mac, but it won’t be the last":
				"d2d30947445157657f425924d96fd139",
			"Cyber Monday Steal: Get 120+ Hours of iOS 11 Dev Training for $15":
				"1da507ba09dfd933733211e182f95db7"
		]
		for (title, expectedID) in expected {
			let item = try #require(
				feed.items.first(where: { $0.title == title }),
				"article '\(title)' missing from Macworld fixture"
			)
			#expect(item.uniqueID == expectedID, "uniqueID for '\(title)' changed")
		}
	}

	@Test func daringFireballRSSItemIsByteStable() throws {
		// Pin title, uniqueID, datePublished, and a substantial contentHTML
		// substring for one specific DF item. DF bodies are CDATA-wrapped and
		// contain numeric entities and nested markup — exactly the surface
		// where subtle parser changes leak through.
		let d = parserData("DaringFireball", "rss", "http://daringfireball.net/")
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(
			feed.items.first(where: { $0.title == "The Dangerous All Writs Act Precedent in the Apple Encryption Case" })
		)
		#expect(item.uniqueID == "tag:daringfireball.net,2016:/linked//6.32163")
		#expect(item.datePublished == Date(timeIntervalSince1970: 1_456_420_033)) // 2016-02-25 17:07:13 UTC
		let html = try #require(item.contentHTML)
		#expect(html.count == 1360)
		// Anchor on a stable substring. Curly quotes survive intact; CDATA
		// pass-through preserves them as UTF-8 bytes rather than remapping
		// to numeric entities.
		#expect(html.hasPrefix("<p>Amy Davidson, writing for The New Yorker:</p>"))
		#expect(html.contains("“all writs necessary"), "curly quotes must survive CDATA pass-through")
	}

	// MARK: - Author shapes (Tier 3 — no-ObjC-comparison protection)

	@Test func emarleyAuthorIsNameOnly() throws {
		// EMarley's feed has authors that are plain names (no email, no URL).
		// Pin this shape so future changes don't accidentally parse names as
		// emails (common RSS spec-vs-reality mismatch).
		let d = parserData("EMarley", "rss", "https://emarley.com/")
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(feed.items.first)
		let author = try #require(item.authors?.first)
		#expect(author.name == "Liz Marley")
		#expect(author.emailAddress == nil)
		#expect(author.url == nil)
	}

	@Test func nonStandardSlashDateFormatParsesCorrectly() throws {
		// kc0011 uses `YYYY/M/D HH:MM:SS` pubDates (Dvbbs.Net-style). Swift DateParser
		// was extended to accept `/` as a date separator; regression here would send
		// all these feeds to the fallback year=1970 path.
		let d = parserData("kc0011", "rss", "http://kc0011.net/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		let expectedJan10 = Calendar(identifier: .gregorian).date(from: DateComponents(
			timeZone: TimeZone(secondsFromGMT: 0),
			year: 2020, month: 1, day: 10
		))!
		let jan10Items = parsedFeed.items.filter {
			guard let date = $0.datePublished else {
				return false
			}
			return date >= expectedJan10 && date < expectedJan10.addingTimeInterval(86400)
		}
		#expect(jan10Items.count > 0, "Expected at least one kc0011 item dated 2020-01-10 — date format regression?")
	}
}
