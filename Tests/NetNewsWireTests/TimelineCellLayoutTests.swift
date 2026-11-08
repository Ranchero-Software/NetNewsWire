//
//  TimelineCellLayoutTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 11/7/26.
//

import AppKit
import Articles
import Testing

@testable import NetNewsWire

@MainActor struct TimelineCellLayoutTests {

	@Test func feedNameAndDateAboveTitle() {
		let appearance = TimelineCellAppearance(showIcon: true, textSize: .medium, iconSize: .large, numberOfLines: 3, showsFullTitles: false, feedNameAndDateAboveTitle: true, showsLargeThumbnails: false)
		let cellData = TimelineCellData(article: makeArticle(), showFeedName: .feed, feedName: "Daring Fireball", byline: nil, iconImage: nil, showIcon: true, thumbnail: nil, showThumbnail: false)

		let layout = TimelineCellLayout(width: 400.0, height: 0.0, cellData: cellData, appearance: appearance)

		#expect(layout.dateRect.maxY <= layout.titleRect.minY)
		#expect(layout.feedNameRect.minY == layout.dateRect.minY)
	}

	@Test func smallThumbnailAlignsWithTitleWhenFeedNameAndDateAboveTitle() {
		let appearance = TimelineCellAppearance(showIcon: true, textSize: .medium, iconSize: .large, numberOfLines: 3, showsFullTitles: false, feedNameAndDateAboveTitle: true, showsLargeThumbnails: false)
		let cellData = TimelineCellData(article: makeArticle(), showFeedName: .feed, feedName: "Daring Fireball", byline: nil, iconImage: nil, showIcon: true, thumbnail: nil, showThumbnail: true)
		let width = 400.0

		let layout = TimelineCellLayout(width: width, height: 0.0, cellData: cellData, appearance: appearance)

		#expect(layout.thumbnailRect.minY == layout.titleRect.minY)
		#expect(layout.dateRect.maxX == width - appearance.cellPadding.right)
		#expect(layout.dateRect.maxY <= layout.thumbnailRect.minY)
	}
}

// MARK: - Helpers

@MainActor private func makeArticle() -> Article {
	let articleID = "article1"
	let status = ArticleStatus(articleID: articleID, read: false, starred: false, dateArrived: Date())
	return Article(accountID: "account1", articleID: articleID, feedID: "feed1", uniqueID: articleID, title: "Apple Announces New MacBook Pro Models", contentHTML: "<p>The new models are available to order today.</p>", contentText: nil, markdown: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, thumbnailURL: nil, datePublished: Date(), dateModified: nil, authors: nil, attachments: nil, status: status)
}
