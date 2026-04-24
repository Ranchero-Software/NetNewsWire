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

	// MARK: - Content pass-through regression

	@Test func xhtmlContentCapturedAsRawBytes() throws {
		// `<content type="xhtml">` in expertopinionent is a rare case where we take
		// the bytes between `<content>` and `</content>` verbatim from the input
		// buffer rather than reconstructing them from SAX events. Preserves the
		// source xmlns, attribute order, and self-closing syntax. A future change
		// that went back to SAX reconstruction would lose those characteristics.
		let d = parserData("expertopinionent", "atom", "http://expertopinionent.typepad.com/my-blog/")
		let parsedFeed = try #require(try FeedParser.parse(d))

		let bodies = parsedFeed.items.compactMap { $0.contentHTML }
		let withXmlns = bodies.contains { $0.contains("xmlns=\"http://www.w3.org/1999/xhtml\"") }
		let withSelfClosing = bodies.contains { $0.contains("<br />") }
		#expect(withXmlns, "expected at least one xhtml body to preserve xmlns declaration")
		#expect(withSelfClosing, "expected at least one xhtml body to preserve self-closing <br />")
	}

	// MARK: - Byte-stability pinning (protects iCloud sync + DB row stability)

	@Test func qemuAtomItemIsByteStable() throws {
		// Pin title, uniqueID, datePublished, and contentHTML start for one
		// specific QEMU release post. QEMU's Atom feed uses the unprefixed
		// default namespace and plain `<content type="html">` bodies — a good
		// complement to the xhtml-passthrough test above.
		let d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(
			feed.items.first(where: { $0.title == "QEMU version 9.0.0 released" })
		)
		#expect(item.uniqueID == "/2024/04/23/qemu-9-0-0")
		#expect(item.datePublished == Date(timeIntervalSince1970: 1_713_913_320)) // 2024-04-23 23:02:00 UTC
		let html = try #require(item.contentHTML)
		#expect(html.count == 2221)
		#expect(html.hasPrefix("<p>We’d like to announce the availability of the QEMU 9.0.0 release"))
		#expect(html.contains("2700+ commits from 220 authors"))
	}

	@Test func qemuAtomSecondItemDateParses() throws {
		// Separate item, different date — catches bugs where datePublished
		// handling accidentally locks onto the first-seen value.
		let d = parserData("qemu", "atom", "https://www.qemu.org/feed.xml")
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(
			feed.items.first(where: { $0.title == "QEMU version 9.1.0 released" })
		)
		#expect(item.datePublished == Date(timeIntervalSince1970: 1_725_404_880)) // 2024-09-03 23:08:00 UTC
	}

	@Test func atomSelfClosingLinkAccepted() throws {
		// Self-closing `<link … />` is the Atom default. Pin it works as
		// expected alongside the non-self-closing form so a scanner change
		// doesn't drop links silently. (Belt-and-braces: qemu already uses
		// this form; explicit test keeps the invariant clear.)
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>self-closing link</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <link rel="alternate" type="text/html" href="http://example.com/article"/>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(feed.items.first)
		#expect(item.url == "http://example.com/article")
	}

	// MARK: - Content type, multiple authors, source (inline fixtures)

	// These tests use inline Atom XML constructed directly, because the real
	// fixtures don't cover these shapes (multiple authors per entry, explicit
	// `type="html"`/`type="text"` on `<content>`, `<source>` attribution).

	@Test func multipleAuthorsPerEntry() throws {
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>Multi-author</title>
		  <link href="http://example.com/"/>
		  <id>urn:example:multi</id>
		  <entry>
		    <id>urn:example:multi:1</id>
		    <title>Joint post</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <author><name>Alice</name></author>
		    <author><name>Bob</name><email>bob@example.com</email></author>
		    <author><name>Carol</name><uri>http://carol.example.com/</uri></author>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let parsedFeed = try #require(try FeedParser.parse(d))
		let item = try #require(parsedFeed.items.first)
		let authors = try #require(item.authors)
		#expect(authors.count == 3)
		let names = Set(authors.compactMap { $0.name })
		#expect(names == ["Alice", "Bob", "Carol"])
		#expect(authors.contains { $0.emailAddress == "bob@example.com" })
		#expect(authors.contains { $0.url == "http://carol.example.com/" })
	}

	@Test func contentTypeHTML() throws {
		// `<content type="html">` — bytes inside are escaped HTML. When decoded,
		// the entity-escaped tags round-trip to real HTML.
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>html content</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <content type="html">&lt;p&gt;Hello &amp; welcome&lt;/p&gt;</content>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let parsedFeed = try #require(try FeedParser.parse(d))
		let item = try #require(parsedFeed.items.first)
		let html = try #require(item.contentHTML)
		#expect(html.contains("<p>Hello & welcome</p>"))
	}

	@Test func contentTypeText() throws {
		// `<content type="text">` — plain text. The parser does not distinguish
		// based on `type` and currently routes all `<content>` bodies through
		// `contentHTML`. Pin down that the body still reaches the caller and
		// entities are decoded.
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>text content</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <content type="text">Just plain &amp; text.</content>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let parsedFeed = try #require(try FeedParser.parse(d))
		let item = try #require(parsedFeed.items.first)
		let body = item.contentText ?? item.contentHTML
		#expect(body?.contains("Just plain & text.") == true)
	}

	// MARK: - Summary / content separation

	@Test func summaryAndContentBothPreserved() throws {
		// russcox entries have both <summary type="text"> and <content type="html">.
		// Both should survive on the ParsedItem as distinct fields.
		let d = parserData("russcox", "atom", "http://research.swtch.com/feed.atom")
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(
			feed.items.first(where: { $0.title == "Transparent Logs for Skeptical Clients" })
		)
		#expect(item.summary == "How an untrusted server can publish a verifiably append-only log.")
		let html = try #require(item.contentHTML)
		#expect(html.contains("Suppose we want to maintain and publish a public, append-only log of data."))
	}

	@Test func summaryOnlyPromotedToContentHTML() throws {
		// When an entry has <summary> but no <content>, the summary is used as
		// contentHTML so the entry has something to render, and the summary
		// slot is cleared to avoid duplication in downstream consumers.
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>summary only</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <summary>Just a summary.</summary>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(feed.items.first)
		#expect(item.contentHTML == "Just a summary.")
		#expect(item.summary == nil)
	}

	@Test func contentOnlyLeavesSummaryNil() throws {
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>content only</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <content>Just content.</content>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(feed.items.first)
		#expect(item.contentHTML == "Just content.")
		#expect(item.summary == nil)
	}

	@Test func summaryAndContentKeptSeparate() throws {
		// When both are present, each goes to its own ParsedItem field —
		// no promotion, no clobbering.
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>both</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <summary>The summary.</summary>
		    <content>The content.</content>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(feed.items.first)
		#expect(item.contentHTML == "The content.")
		#expect(item.summary == "The summary.")
	}

	@Test func xhtmlSummaryCapturedAsRawBytes() throws {
		// `<summary type="xhtml">` uses the raw-content-capture path, like
		// `<content type="xhtml">`. The end-element pass must not clobber it
		// with nil when no characters were accumulated.
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>xhtml summary</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <summary type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p>Hello <em>world</em>.</p></div></summary>
		    <content>Body.</content>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let feed = try #require(try FeedParser.parse(d))
		let item = try #require(feed.items.first)
		#expect(item.contentHTML == "Body.")
		let summary = try #require(item.summary)
		#expect(summary.contains("<p>Hello <em>world</em>.</p>"))
	}

	@Test func contentTypeDefault() throws {
		// No `type` attribute — RFC 4287 specifies default is "text". The
		// parser treats it as plain text (same path as `type="text"`).
		let xml = """
		<?xml version="1.0" encoding="utf-8"?>
		<feed xmlns="http://www.w3.org/2005/Atom">
		  <title>t</title><id>urn:t</id>
		  <entry>
		    <id>urn:t:1</id>
		    <title>default content</title>
		    <updated>2020-05-01T00:00:00Z</updated>
		    <content>Default is text.</content>
		  </entry>
		</feed>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(xml.utf8))
		let parsedFeed = try #require(try FeedParser.parse(d))
		let item = try #require(parsedFeed.items.first)
		// Either contentText or contentHTML should surface the string — the
		// precise routing is an implementation detail, but it must not vanish.
		let body = item.contentText ?? item.contentHTML
		#expect(body?.contains("Default is text.") == true)
	}
}
