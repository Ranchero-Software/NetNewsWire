//
//  FeedParserTypeTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser
import RSParserObjC

@Suite struct FeedParserTypeTests {

	// MARK: - HTML

	@Test("HTML files are detected as notAFeed",
	      arguments: [
	          ("DaringFireball", "html", "http://daringfireball.net/"),
	          ("furbo", "html", "http://furbo.org/"),
	          ("inessential", "html", "http://inessential.com/"),
	          ("sixcolors", "html", "https://sixcolors.com/")
	      ])
	func htmlType(_ filename: String, _ ext: String, _ url: String) {
		let d = parserData(filename, ext, url)
		#expect(feedType(d) == .notAFeed)
	}

	// MARK: - RSS

	@Test("RSS feeds are detected as .rss",
	      arguments: [
	          ("EMarley", "rss", "https://medium.com/@emarley"),
	          ("scriptingNews", "rss", "http://scripting.com/"),
	          ("KatieFloyd", "rss", "https://katiefloyd.com/"),
	          ("manton", "rss", "http://manton.org/"),
	          ("dcrainmaker", "xml", "https://www.dcrainmaker.com/"),
	          ("macworld", "rss", "https://www.macworld.com/"),
	          ("natasha", "xml", "https://www.natashatherobot.com/"),
	          ("donthitsave", "xml", "http://donthitsave.com/donthitsavefeed.xml"),
	          ("bio", "rdf", "http://connect.biorxiv.org/"),
	          ("phpxml", "rss", "https://www.fcutrecht.net/")
	      ])
	func rssType(_ filename: String, _ ext: String, _ url: String) {
		let d = parserData(filename, ext, url)
		#expect(feedType(d) == .rss)
	}

	// MARK: - Atom

	@Test("Atom feeds are detected as .atom",
	      arguments: [
	          // File extension is .rss, but it’s really an Atom feed.
	          ("DaringFireball", "rss", "http://daringfireball.net/"),
	          ("OneFootTsunami", "atom", "http://onefoottsunami.com/"),
	          ("russcox", "atom", "https://research.swtch.com/")
	      ])
	func atomType(_ filename: String, _ ext: String, _ url: String) {
		let d = parserData(filename, ext, url)
		#expect(feedType(d) == .atom)
	}

	// MARK: - RSS-in-JSON

	@Test func scriptingNewsJSONType() {
		let d = parserData("ScriptingNews", "json", "http://scripting.com/")
		#expect(feedType(d) == .rssInJSON)
	}

	// MARK: - JSON Feed

	@Test("JSON Feeds are detected as .jsonFeed",
	      arguments: [
	          ("inessential", "json", "http://inessential.com/"),
	          ("allthis", "json", "http://leancrew.com/allthis/"),
	          ("curt", "json", "http://curtclifton.net/"),
	          ("pxlnv", "json", "http://pxlnv.com/"),
	          ("rose", "json", "https://www.rosemaryorchard.com/")
	      ])
	func jsonFeedType(_ filename: String, _ ext: String, _ url: String) {
		let d = parserData(filename, ext, url)
		#expect(feedType(d) == .jsonFeed)
	}

	// MARK: - Unknown

	@Test func partialAllThisUnknownFeedType() {
		// In the case of this feed, the partial data isn’t enough to detect that it’s a JSON Feed.
		// The type detector should return .unknown rather than .notAFeed.
		let d = parserData("allthis-partial", "json", "http://leancrew.com/allthis/")
		#expect(feedType(d, isPartialData: true) == .unknown)
	}
}

// MARK: - Shared helper

func parserData(_ filename: String, _ fileExtension: String, _ url: String) -> ParserData {
	let filename = "Resources/\(filename)"
	let path = Bundle.module.path(forResource: filename, ofType: fileExtension)!
	let data = try! Data(contentsOf: URL(fileURLWithPath: path))
	return ParserData(url: url, data: data)
}
