//
//  HTMLMetadataTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser

@Suite struct HTMLMetadataTests {

	@Test func daringFireball() throws {
		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.favicons.first?.urlString == "http://daringfireball.net/graphics/favicon.ico?v=005")

		#expect(metadata.feedLinks.count == 1)

		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == nil)
		#expect(feedLink.type == "application/atom+xml")
		#expect(feedLink.urlString == "http://daringfireball.net/feeds/main")
	}

	@Test func furbo() throws {
		let d = parserData("furbo", "html", "http://furbo.org/")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.favicons.first?.urlString == "http://furbo.org/favicon.ico")

		#expect(metadata.feedLinks.count == 1)

		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == "Iconfactory News Feed")
		#expect(feedLink.type == "application/rss+xml")
	}

	@Test func inessential() throws {
		let d = parserData("inessential", "html", "http://inessential.com/")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.favicons.first?.urlString == nil)

		#expect(metadata.feedLinks.count == 1)
		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == "RSS")
		#expect(feedLink.type == "application/rss+xml")
		#expect(feedLink.urlString == "http://inessential.com/xml/rss.xml")

		#expect(metadata.appleTouchIcons.count == 0)
	}

	@Test func sixColors() throws {
		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.favicons.first?.urlString == "https://sixcolors.com/images/favicon.ico")

		#expect(metadata.feedLinks.count == 1)
		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == "RSS")
		#expect(feedLink.type == "application/rss+xml")
		#expect(feedLink.urlString == "http://feedpress.me/sixcolors")

		#expect(metadata.appleTouchIcons.count == 6)
		let icon = metadata.appleTouchIcons[3]
		#expect(icon.rel == "apple-touch-icon")
		#expect(icon.sizes == "120x120")
		#expect(icon.urlString == "https://sixcolors.com/apple-touch-icon-120.png")
	}

	@Test func cocoOGImage() throws {
		let d = parserData("coco", "html", "https://www.theatlantic.com/entertainment/archive/2017/11/coco-is-among-pixars-best-movies-in-years/546695/")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		let openGraphData = metadata.openGraphProperties
		let image = try #require(openGraphData.images.first)
		#expect(image.url == "https://cdn.theatlantic.com/assets/media/img/mt/2017/11/1033101_first_full_length_trailer_arrives_pixars_coco/facebook.jpg?1511382177")
	}

	@Test func cocoTwitterImage() throws {
		let d = parserData("coco", "html", "https://www.theatlantic.com/entertainment/archive/2017/11/coco-is-among-pixars-best-movies-in-years/546695/")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		let twitterData = metadata.twitterProperties
		let imageURL = try #require(twitterData.imageURL)
		#expect(imageURL == "https://cdn.theatlantic.com/assets/media/img/mt/2017/11/1033101_first_full_length_trailer_arrives_pixars_coco/facebook.jpg?1511382177")
	}

	@Test func youTube() throws {
		// YouTube is a special case — the feed links appear after the head section, in the body section.
		let d = parserData("YouTubeTheVolvoRocks", "html", "https://www.youtube.com/user/TheVolvorocks")
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.feedLinks.count == 1)
		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == "RSS")
		#expect(feedLink.type == "application/rss+xml")
		#expect(feedLink.urlString == "https://www.youtube.com/feeds/videos.xml?channel_id=UCct7QF2jcWRY6dhXWMSq9LQ")
	}

	// MARK: - Inline fixture tests

	@Test func bothRSSAndAtomFeedLinksReported() throws {
		// When a page offers both RSS and Atom, both should appear in feedLinks.
		// Feed-discovery UI can then pick whichever it prefers.
		let html = """
		<html><head>
		<link rel="alternate" type="application/rss+xml" title="RSS" href="/feed.rss">
		<link rel="alternate" type="application/atom+xml" title="Atom" href="/feed.atom">
		</head><body></body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		#expect(metadata.feedLinks.count == 2)
		let types = Set(metadata.feedLinks.compactMap { $0.type })
		#expect(types == ["application/rss+xml", "application/atom+xml"])
	}

	@Test func pageWithNoHeadReturnsEmptyMetadata() {
		// Malformed page, no <head>, no <link> / <meta>. Parser must not crash
		// and must report an empty-but-usable metadata struct.
		let html = "<html><body>Hello world</body></html>"
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		#expect(metadata.feedLinks.isEmpty)
		#expect(metadata.favicons.isEmpty)
		#expect(metadata.appleTouchIcons.isEmpty)
	}

	@Test func relativeFaviconResolvedAgainstPageURL() throws {
		// Relative favicon href must resolve against the page URL so downloaders
		// don't have to. Also checks that multiple apple-touch-icons are preserved.
		let html = """
		<html><head>
		<link rel="icon" href="/favicon.ico">
		<link rel="apple-touch-icon" sizes="60x60" href="/touch-60.png">
		<link rel="apple-touch-icon" sizes="120x120" href="/touch-120.png">
		</head><body></body></html>
		"""
		let d = ParserData(url: "http://example.com/some/page.html", data: Data(html.utf8))
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		#expect(metadata.favicons.first?.urlString == "http://example.com/favicon.ico")
		#expect(metadata.appleTouchIcons.count == 2)
		let sizes = Set(metadata.appleTouchIcons.compactMap { $0.sizes })
		#expect(sizes == ["60x60", "120x120"])
		let urls = Set(metadata.appleTouchIcons.compactMap { $0.urlString })
		#expect(urls == [
			"http://example.com/touch-60.png",
			"http://example.com/touch-120.png"
		])
	}

	@Test func typelessFeedLinkAccepted() throws {
		// Some pages advertise their feed with `<link rel="alternate" href=…>`
		// and no `type` attribute. We accept those as feed links so auto-
		// discovery still works. An alternate with an explicit non-feed type
		// (`text/html` for i18n variants etc.) is still filtered out — see
		// `nonFeedTypedAlternateRejected`.
		let html = """
		<html><head>
		<link rel="alternate" href="/feed.xml">
		</head><body></body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		#expect(metadata.feedLinks.count == 1)
		let link = try #require(metadata.feedLinks.first)
		#expect(link.urlString == "http://example.com/feed.xml")
		#expect(link.type == nil)
	}

	@Test func nonFeedTypedAlternateRejected() {
		// `rel="alternate"` with an explicit non-feed type must NOT be treated
		// as a feed link. This is the other half of the typeless-accepted rule:
		// we trust an explicit type when it says "not a feed."
		let html = """
		<html><head>
		<link rel="alternate" hreflang="fr" type="text/html" href="/fr/page.html">
		</head><body></body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let metadata = HTMLMetadataParser.htmlMetadata(with: d)
		#expect(metadata.feedLinks.isEmpty)
	}
}
