//
//  TimelineCellData.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles

struct TimelineCellData {
	
	let title: String
	let text: String
	let dateString: String
	let feedName: String
	let showFeedName: Bool
	let iconImage: IconImage? // feed icon, user avatar, or favicon
	let showIcon: Bool // Make space even when icon is nil
	let featuredImage: NSImage? // image from within the article
	let read: Bool
	let starred: Bool

	init(article: Article, showFeedName: Bool, feedName: String?, iconImage: IconImage?, showIcon: Bool, featuredImage: NSImage?) {

		self.title = ArticleStringFormatter.truncatedTitle(article)
		self.text = ArticleStringFormatter.truncatedSummary(article)

		self.dateString = ArticleStringFormatter.dateString(article.logicalDatePublished)

		if let feedName = feedName {
			self.feedName = ArticleStringFormatter.truncatedFeedName(feedName)
		}
		else {
			self.feedName = ""
		}

		self.showFeedName = showFeedName

		self.showIcon = showIcon
		self.iconImage = iconImage
		self.featuredImage = featuredImage
		
		self.read = article.status.read
		self.starred = article.status.starred
	}

	init() { //Empty
		self.title = ""
		self.text = ""
		self.dateString = ""
		self.feedName = ""
		self.showFeedName = false
		self.showIcon = false
		self.iconImage = nil
		self.featuredImage = nil
		self.read = true
		self.starred = false
	}
}
