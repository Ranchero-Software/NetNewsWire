//
//  TimelineRowHeightPerformanceTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 11/7/26.
//

import AppKit
import Articles
import Images
import XCTest

@testable import NetNewsWire

/// What one timeline row height costs, including building its cell data, as the timeline’s
/// heightOfRow would. NSTableView asks for every row’s height when it reloads.
///
/// Cold: each pass uses articles it hasn’t seen, so text measuring isn’t cached.
/// Warm: each pass uses the same articles, as after a reload at the same width.
///
/// Benchmark: release build, Apple Silicon, 3,000 articles at 400 points wide:
///
///     Test     Total          Per row
///     -------  ------------   -------------
///     Cold     0.321 s        0.000107 s
///     Warm     0.024 s        0.000008 s
///
@MainActor final class TimelineRowHeightPerformanceTests: XCTestCase {

	private static let articleCount = 3000
	private static let rowWidth: CGFloat = 400.0
	private static let warmArticles = makeTimelineArticles(count: articleCount, pass: 0)

	func testRowHeightsCold() {
		var pass = 1
		measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
			let articles = makeTimelineArticles(count: Self.articleCount, pass: pass)
			pass += 1
			startMeasuring()
			Self.calculateRowHeights(articles)
			stopMeasuring()
		}
	}

	func testRowHeightsWarm() {
		Self.calculateRowHeights(Self.warmArticles)
		measure {
			Self.calculateRowHeights(Self.warmArticles)
		}
	}
}

// MARK: - Helpers

private extension TimelineRowHeightPerformanceTests {

	static let appearance = TimelineCellAppearance(showIcon: true, textSize: .medium, iconSize: .large, numberOfLines: 3, showsFullTitles: false, showsLargeThumbnails: false)

	static func calculateRowHeights(_ articles: [Article]) {
		for article in articles {
			let cellData = TimelineCellData(article: article, showFeedName: .feed, feedName: "Feed Name", byline: nil, iconImage: nil, showIcon: true, thumbnail: nil, showThumbnail: false)
			_ = TimelineCellLayout.height(for: rowWidth, cellData: cellData, appearance: appearance)
		}
	}
}

/// Titles and summaries of varied length. `pass` makes every string unique to that pass.
@MainActor private func makeTimelineArticles(count: Int, pass: Int) -> [Article] {
	let sampleTitles = [
		"Short title",
		"A title of moderate length that probably wraps onto a second line",
		"A long title that goes on for quite a while, the way some sites write them, so that it needs three or four lines in a narrow timeline",
		"",
		"Title with <b>bold</b> and <i>italic</i> and émoji 🎉"
	]
	let sampleBodies = [
		"<p>A short body.</p>",
		"<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.</p>",
		"<p>A body with <a href=\"#\">a link</a> and some &amp; entities, long enough to fill a preview with a couple of lines of text.</p>"
	]
	var articles = [Article]()
	articles.reserveCapacity(count)
	for i in 0..<count {
		let articleID = "pass\(pass)-article\(i)"
		let title = sampleTitles[i % sampleTitles.count]
		let uniqueTitle = title.isEmpty ? "" : "\(title) \(pass)-\(i)"
		let body = sampleBodies[i % sampleBodies.count].replacingOccurrences(of: "</p>", with: " \(pass)-\(i)</p>")
		let status = ArticleStatus(articleID: articleID, read: false, starred: false, dateArrived: Date())
		let article = Article(accountID: "account1", articleID: articleID, feedID: "feed1", uniqueID: articleID, title: uniqueTitle, contentHTML: body, contentText: nil, markdown: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, thumbnailURL: nil, datePublished: Date(), dateModified: nil, authors: nil, attachments: nil, status: status)
		articles.append(article)
	}
	return articles
}
