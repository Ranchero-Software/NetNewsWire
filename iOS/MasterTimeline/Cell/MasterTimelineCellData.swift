//
//  MasterTimelineCellData.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import Articles

struct MasterTimelineCellData {
	
	let title: String
	let summary: String
	let dateString: String
	let feedName: String
	let showFeedName: Bool
	let iconImage: IconImage? // feed icon, user avatar, or favicon
	let showIcon: Bool // Make space even when icon is nil
	let featuredImage: UIImage? // image from within the article
	let read: Bool
	let starred: Bool
	let numberOfLines: Int
	let iconSize: IconSize

	init(article: Article, showFeedName: Bool, feedName: String?, iconImage: IconImage?, showIcon: Bool, featuredImage: UIImage?, numberOfLines: Int, iconSize: IconSize) {

		self.title = ArticleStringFormatter.truncatedTitle(article)
		self.summary = ArticleStringFormatter.truncatedSummary(article)

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
		self.numberOfLines = numberOfLines
		self.iconSize = iconSize
		
	}

	init() { //Empty
		self.title = ""
		self.summary = ""
		self.dateString = ""
		self.feedName = ""
		self.showFeedName = false
		self.showIcon = false
		self.iconImage = nil
		self.featuredImage = nil
		self.read = true
		self.starred = false
		self.numberOfLines = 0
		self.iconSize = .medium
	}
	
}
