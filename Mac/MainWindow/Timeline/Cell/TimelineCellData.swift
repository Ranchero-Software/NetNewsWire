//
//  TimelineCellData.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles

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
	let read: Bool
	let starred: Bool
	let thumbnailURL: URL?

	init(article: Article, showFeedName: TimelineShowFeedName, feedName: String?, byline: String?, iconImage: IconImage?, showIcon: Bool) {

		self.title = ArticleStringFormatter.shared.truncatedTitle(article)
		self.attributedTitle = ArticleStringFormatter.shared.attributedTruncatedTitle(article)

		let truncatedSummary = ArticleStringFormatter.shared.truncatedSummary(article)
		if self.title.isEmpty && truncatedSummary.isEmpty {
			self.text = Self.noText
		} else {
			self.text = truncatedSummary
		}

		self.dateString = ArticleStringFormatter.shared.dateString(article.logicalDatePublished)

		if let feedName = feedName {
			self.feedName = ArticleStringFormatter.shared.truncatedFeedName(feedName)
		} else {
			self.feedName = ""
		}

		if let byline = byline {
			self.byline = byline
		} else {
			self.byline = ""
		}

		self.showFeedName = showFeedName

		self.showIcon = showIcon
		self.iconImage = iconImage

		self.read = article.status.read
		self.starred = article.status.starred
		self.thumbnailURL = article.firstBodyImageURL
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
		self.read = true
		self.starred = false
		self.attributedTitle = NSAttributedString()
		self.thumbnailURL = nil
	}
}
