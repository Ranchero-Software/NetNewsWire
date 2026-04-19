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
import RSParserObjC

@Suite struct HTMLMetadataTests {

	@Test func daringFireball() throws {
		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.favicons.first?.urlString == "http://daringfireball.net/graphics/favicon.ico?v=005")

		#expect(metadata.feedLinks.count == 1)

		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == nil)
		#expect(feedLink.type == "application/atom+xml")
		#expect(feedLink.urlString == "http://daringfireball.net/feeds/main")
	}

	@Test func furbo() throws {
		let d = parserData("furbo", "html", "http://furbo.org/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.favicons.first?.urlString == "http://furbo.org/favicon.ico")

		#expect(metadata.feedLinks.count == 1)

		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == "Iconfactory News Feed")
		#expect(feedLink.type == "application/rss+xml")
	}

	@Test func inessential() throws {
		let d = parserData("inessential", "html", "http://inessential.com/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

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
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

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
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)
		let openGraphData = metadata.openGraphProperties
		let image = try #require(openGraphData.images.first)
		#expect(image.url == "https://cdn.theatlantic.com/assets/media/img/mt/2017/11/1033101_first_full_length_trailer_arrives_pixars_coco/facebook.jpg?1511382177")
	}

	@Test func cocoTwitterImage() throws {
		let d = parserData("coco", "html", "https://www.theatlantic.com/entertainment/archive/2017/11/coco-is-among-pixars-best-movies-in-years/546695/")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)
		let twitterData = metadata.twitterProperties
		let imageURL = try #require(twitterData.imageURL)
		#expect(imageURL == "https://cdn.theatlantic.com/assets/media/img/mt/2017/11/1033101_first_full_length_trailer_arrives_pixars_coco/facebook.jpg?1511382177")
	}

	@Test func youTube() throws {
		// YouTube is a special case — the feed links appear after the head section, in the body section.
		let d = parserData("YouTubeTheVolvoRocks", "html", "https://www.youtube.com/user/TheVolvorocks")
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: d)

		#expect(metadata.feedLinks.count == 1)
		let feedLink = try #require(metadata.feedLinks.first)
		#expect(feedLink.title == "RSS")
		#expect(feedLink.type == "application/rss+xml")
		#expect(feedLink.urlString == "https://www.youtube.com/feeds/videos.xml?channel_id=UCct7QF2jcWRY6dhXWMSq9LQ")
	}
}
