//
//  ParserComparisonBenchmark.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
import RSParser
import RSParserObjC

// Side-by-side timing: old ObjC RSRSSParser/RSAtomParser (libxml2-backed)
// vs the new Swift FeedParser (pure-Swift XMLSAXParser-backed).
// Requires the old ObjC parser files temporarily restored.

final class ParserComparisonBenchmark: XCTestCase {

	private let rssFixtures: [(name: String, ext: String, url: String)] = [
		("scriptingNews", "rss", "http://scripting.com/"),
		("KatieFloyd", "rss", "http://katiefloyd.com/"),
		("EMarley", "rss", "https://medium.com/@emarley"),
		("manton", "rss", "http://manton.org/"),
		("DaringFireball", "rss", "http://daringfireball.net/"),
		("macworld", "rss", "https://www.macworld.com/"),
		("atp", "rss", "http://atp.fm/"),
		("cloudblog", "rss", "https://cloudblog.withgoogle.com/"),
		("aktuality", "rss", "https://www.aktuality.sk/"),
		("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
	]

	private let atomFixtures: [(name: String, ext: String, url: String)] = [
		("DaringFireball", "atom", "https://daringfireball.net/feeds/main"),
		("allthis", "atom", "http://leancrew.com/all-this"),
		("qemu", "atom", "https://www.qemu.org/feed.xml"),
		("yakubin", "atom", "https://yakubin.com/notes/atom.xml"),
		("4fsodonline", "atom", "http://4fsodonline.blogspot.com/feeds/posts/default"),
		("OneFootTsunami", "atom", "http://onefoottsunami.com/"),
		("neverworkintheory", "atom", "https://neverworkintheory.org/atom.xml"),
		("expertopinionent", "atom", "http://expertopinionent.typepad.com/my-blog/"),
		("root-author", "atom", "https://fvsch.com/feed.xml"),
		("russcox", "atom", "https://research.swtch.com/")
	]

	private let trialsPerFixture = 20

	func testRSSComparison() {
		runComparison(label: "RSS", fixtures: rssFixtures)
	}

	func testAtomComparison() {
		runComparison(label: "Atom", fixtures: atomFixtures)
	}

	// MARK: - Runner

	private func runComparison(label: String, fixtures: [(name: String, ext: String, url: String)]) {
		let parserDatas = fixtures.map { parserData($0.name, $0.ext, $0.url) }

		// Warm up both paths with one pass each.
		for d in parserDatas {
			_ = RSRSSParser.parseFeed(with: d)
			_ = RSAtomParser.parseFeed(with: d)
			_ = try? FeedParser.parse(d)
		}

		var objcTotalNs: UInt64 = 0
		var swiftTotalNs: UInt64 = 0

		for _ in 0..<trialsPerFixture {
			for d in parserDatas {
				let objcStart = DispatchTime.now()
				if label == "RSS" {
					_ = RSRSSParser.parseFeed(with: d)
				} else {
					_ = RSAtomParser.parseFeed(with: d)
				}
				let objcEnd = DispatchTime.now()
				objcTotalNs += objcEnd.uptimeNanoseconds - objcStart.uptimeNanoseconds

				let swiftStart = DispatchTime.now()
				_ = try? FeedParser.parse(d)
				let swiftEnd = DispatchTime.now()
				swiftTotalNs += swiftEnd.uptimeNanoseconds - swiftStart.uptimeNanoseconds
			}
		}

		let totalFeeds = parserDatas.count * trialsPerFixture
		let objcUsPerFeed = Double(objcTotalNs) / 1_000.0 / Double(totalFeeds)
		let swiftUsPerFeed = Double(swiftTotalNs) / 1_000.0 / Double(totalFeeds)
		let speedup = objcUsPerFeed / swiftUsPerFeed

		print("""

		─── \(label) parser comparison (\(parserDatas.count) fixtures × \(trialsPerFixture) trials) ───
		ObjC  (libxml2):  \(String(format: "%7.1f µs/feed", objcUsPerFeed))
		Swift (pure):     \(String(format: "%7.1f µs/feed", swiftUsPerFeed))
		Speedup:          \(String(format: "%.2fx", speedup))
		───────────────────────────────────────────────────────────────────────
		""")
	}
}
