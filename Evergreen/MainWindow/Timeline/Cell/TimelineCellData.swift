//
//  TimelineCellData.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Data

var attributedTitleCache = [String: NSAttributedString]()
var attributedDateCache = [String: NSAttributedString]()
var attributedFeedNameCache = [String: NSAttributedString]()

struct TimelineCellData {
	
	let title: String
	let text: String
	let attributedTitle: NSAttributedString //title + text
	let dateString: String
	let feedName: String
	let showFeedName: Bool
	let avatar: NSImage? // feed icon, user avatar, or favicon
	let showAvatar: Bool // Make space even when avatar is nil
	let featuredImage: NSImage? // image from within the article
	let read: Bool
	let starred: Bool

	init(article: Article, appearance: TimelineCellAppearance, showFeedName: Bool, feedName: String?, avatar: NSImage?, showAvatar: Bool, featuredImage: NSImage?) {

		self.title = timelineTruncatedTitle(article)
		self.text = timelineTruncatedSummary(article)

		let attributedTitleCacheKey = "_title: " + self.title + "_text: " + self.text
		if let s = attributedTitleCache[attributedTitleCacheKey] {
			self.attributedTitle = s
		}
		else {
			self.attributedTitle = attributedTitleString(title, text, appearance)
			attributedTitleCache[attributedTitleCacheKey] = self.attributedTitle
		}

		self.dateString = timelineDateString(article.logicalDatePublished)

		if let feedName = feedName {
			self.feedName = timelineTruncatedFeedName(feedName)
		}
		else {
			self.feedName = ""
		}

		self.showFeedName = showFeedName

		self.showAvatar = showAvatar
		self.avatar = avatar
		self.featuredImage = featuredImage
		
		self.read = article.status.read
		self.starred = article.status.starred
	}

	init() { //Empty
		
		self.title = ""
		self.attributedTitle = NSAttributedString(string: "")
		self.text = ""
		self.dateString = ""
		self.feedName = ""
		self.showFeedName = false
		self.showAvatar = false
		self.avatar = nil
		self.featuredImage = nil
		self.read = true
		self.starred = false
	}

	static func emptyCache() {

		attributedTitleCache = [String: NSAttributedString]()
		attributedDateCache = [String: NSAttributedString]()
		attributedFeedNameCache = [String: NSAttributedString]()
	}
}

let emptyCellData = TimelineCellData()

private func attributedTitleString(_ title: String, _ text: String, _ appearance: TimelineCellAppearance) -> NSAttributedString {
	
	if !title.isEmpty && !text.isEmpty {
		
		let titleMutable = NSMutableAttributedString(string: title, attributes: [NSAttributedStringKey.foregroundColor: appearance.titleColor, NSAttributedStringKey.font: appearance.titleFont])
//		let attributedText = NSAttributedString(string: " " + text, attributes: [NSAttributedStringKey.foregroundColor: appearance.textColor, NSAttributedStringKey.font: appearance.textFont])
//		titleMutable.append(attributedText)
		return titleMutable
	}
	
	if !title.isEmpty && text.isEmpty {
		return NSAttributedString(string: title, attributes: [NSAttributedStringKey.foregroundColor: appearance.titleColor, NSAttributedStringKey.font: appearance.titleFont])
	}
	
	return NSAttributedString(string: text, attributes: [NSAttributedStringKey.foregroundColor: appearance.textOnlyColor, NSAttributedStringKey.font: appearance.textOnlyFont])
}

