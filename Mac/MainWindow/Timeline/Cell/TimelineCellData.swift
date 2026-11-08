//
//  TimelineCellData.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles
import Images

@MainActor struct TimelineCellData {

	private static let noText = NSLocalizedString("(No Text)", comment: "No Text")

	let title: String
	let attributedTitle: NSAttributedString
	let text: String
	let dateString: String
	let feedName: String
	let byline: String
	let showFeedName: TimelineShowFeedName
	let iconImage: IconImage? // feed icon, user avatar, or favicon
	let showIcon: Bool // Make space even when icon is nil
	let thumbnail: NSImage?
	let showThumbnail: Bool // Make space even when thumbnail is nil
	let read: Bool
	let starred: Bool

	init(article: Article, showFeedName: TimelineShowFeedName, feedName: String?, byline: String?, iconImage: IconImage?, showIcon: Bool, thumbnail: NSImage?, showThumbnail: Bool) {

		self.title = ArticleStringFormatter.shared.truncatedTitle(article)
		self.attributedTitle = ArticleStringFormatter.shared.attributedTruncatedTitle(article)
		self.text = Self.summaryText(for: article, title: self.title)

		self.dateString = ArticleStringFormatter.shared.dateString(article.logicalDatePublished)

		if let feedName = feedName {
			self.feedName = ArticleStringFormatter.shared.truncatedFeedName(feedName)
		} else {
			self.feedName = ""
		}

		// Falls back to the feed name so the line is never empty.
		if let byline, !byline.isEmpty {
			self.byline = byline
		} else {
			self.byline = self.feedName
		}

		self.showFeedName = showFeedName

		self.showIcon = showIcon
		self.iconImage = iconImage

		self.thumbnail = thumbnail
		self.showThumbnail = showThumbnail

		self.read = article.status.read
		self.starred = article.status.starred
	}

	/// The article’s summary, or “(No Text)” when it has neither a title nor a summary.
	static func summaryText(for article: Article, title: String) -> String {
		let truncatedSummary = ArticleStringFormatter.shared.truncatedSummary(article)
		if title.isEmpty && truncatedSummary.isEmpty {
			return noText
		}
		return truncatedSummary
	}

	init() { // Empty
		self.title = ""
		self.text = ""
		self.dateString = ""
		self.feedName = ""
		self.byline = ""
		self.showFeedName = .none
		self.showIcon = false
		self.iconImage = nil
		self.thumbnail = nil
		self.showThumbnail = false
		self.read = true
		self.starred = false
		self.attributedTitle = NSAttributedString()
	}
}
