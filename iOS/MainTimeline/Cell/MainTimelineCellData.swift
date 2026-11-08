//
//  MainTimelineCellData.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import Articles
import Images

@MainActor struct MainTimelineCellData {

	private static let noText = NSLocalizedString("(No Text)", comment: "No Text")
	static let fullTitleMaximumNumberOfLines = 12

	let accountID: String
	let articleID: String
	let title: String
	let attributedTitle: NSAttributedString
	let summary: String
	let dateString: String
	let feedName: String
	let byline: String
	let showFeedName: ShowFeedName
	let iconImage: IconImage? // feed icon, user avatar, or favicon
	let showIcon: Bool // Make space even when icon is nil
	let read: Bool
	let starred: Bool
	let numberOfLines: Int // Shared by the title and summary, or the title alone with showsFullTitles
	let iconSize: IconSize
	let thumbnail: UIImage?
	let showThumbnail: Bool // Make space even when thumbnail is nil
	let thumbnailsDisplay: TimelineThumbnailsDisplay
	let fadesReadArticles: Bool
	let feedNameAndDateAboveTitle: Bool
	let showsFullTitles: Bool

	/// With `showsFullTitles`, the title gets up to `fullTitleMaximumNumberOfLines` lines and there’s no summary.
	init(article: Article, showFeedName: ShowFeedName, feedName: String?, byline: String?, iconImage: IconImage?, showIcon: Bool, numberOfLines: Int, iconSize: IconSize, thumbnail: UIImage?, showThumbnail: Bool, thumbnailsDisplay: TimelineThumbnailsDisplay, fadesReadArticles: Bool, feedNameAndDateAboveTitle: Bool, showsFullTitles: Bool) {

		self.accountID = article.accountID
		self.articleID = article.articleID
		self.title = ArticleStringFormatter.shared.truncatedTitle(article)
		self.attributedTitle = ArticleStringFormatter.shared.attributedTruncatedTitle(article)

		let truncatedSummary = ArticleStringFormatter.shared.truncatedSummary(article)
		if self.title.isEmpty && truncatedSummary.isEmpty {
			self.summary = Self.noText
		} else {
			self.summary = truncatedSummary
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
		self.numberOfLines = showsFullTitles ? Self.fullTitleMaximumNumberOfLines : numberOfLines
		self.iconSize = iconSize
		self.thumbnail = thumbnail
		self.showThumbnail = showThumbnail
		self.thumbnailsDisplay = thumbnailsDisplay
		self.fadesReadArticles = fadesReadArticles
		self.feedNameAndDateAboveTitle = feedNameAndDateAboveTitle
		self.showsFullTitles = showsFullTitles
	}

	init() { // Empty
		self.accountID = ""
		self.articleID = ""
		self.title = ""
		self.attributedTitle = NSAttributedString()
		self.summary = ""
		self.dateString = ""
		self.feedName = ""
		self.byline = ""
		self.showFeedName = .none
		self.showIcon = false
		self.iconImage = nil
		self.read = true
		self.starred = false
		self.numberOfLines = 0
		self.iconSize = .medium
		self.thumbnail = nil
		self.showThumbnail = false
		self.thumbnailsDisplay = .none
		self.fadesReadArticles = false
		self.feedNameAndDateAboveTitle = false
		self.showsFullTitles = false
	}

}
