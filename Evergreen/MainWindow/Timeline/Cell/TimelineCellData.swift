//
//  TimelineCellData.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import DataModel

var attributedTitleCache = [String: NSAttributedString]()
var attributedDateCache = [String: NSAttributedString]()
var attributedFeedNameCache = [String: NSAttributedString]()

struct TimelineCellData {
	
	let title: String
	let text: String
	let attributedTitle: NSAttributedString //title + text
	let dateString: String
	let attributedDateString: NSAttributedString
	let feedName: String
	let attributedFeedName: NSAttributedString
	let showFeedName: Bool
	let favicon: NSImage?
	let read: Bool

	init(article: Article, appearance: TimelineCellAppearance, showFeedName: Bool) {
		
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
		if let s = attributedDateCache[self.dateString] {
			self.attributedDateString = s
		}
		else {
			self.attributedDateString = NSAttributedString(string: self.dateString, attributes: [NSForegroundColorAttributeName: appearance.dateColor, NSFontAttributeName: appearance.dateFont])
			attributedDateCache[self.dateString] = self.attributedDateString
		}

		if let feed = article.feed {
			self.feedName = timelineTruncatedFeedName(feed)
		}
		else {
			self.feedName = ""
		}
		if let s = attributedFeedNameCache[self.dateString] {
			self.attributedFeedName = s
		}
		else {
			self.attributedFeedName = NSAttributedString(string: self.feedName, attributes: [NSForegroundColorAttributeName: appearance.feedNameColor, NSFontAttributeName: appearance.feedNameFont])
			attributedFeedNameCache[self.feedName] = self.attributedFeedName
		}

		self.showFeedName = showFeedName

		self.favicon = nil
		
		if let status = article.status {
			self.read = status.read
		}
		else {
			self.read = false
		}
	}

	init() { //Empty
		
		self.title = ""
		self.attributedTitle = NSAttributedString(string: "")
		self.text = ""
		self.dateString = ""
		self.attributedDateString = NSAttributedString(string: "")
		self.feedName = ""
		self.attributedFeedName = NSAttributedString(string: "")
		self.showFeedName = false
		self.favicon = nil
		self.read = true
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
		
		let titleMutable = NSMutableAttributedString(string: title, attributes: [NSForegroundColorAttributeName: appearance.titleColor, NSFontAttributeName: appearance.titleFont])
		let attributedText = NSAttributedString(string: "\n" + text, attributes: [NSForegroundColorAttributeName: appearance.textColor, NSFontAttributeName: appearance.textFont])
		titleMutable.append(attributedText)
		return titleMutable
	}
	
	if !title.isEmpty && text.isEmpty {
		return NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: appearance.titleColor, NSFontAttributeName: appearance.titleFont])
	}
	
	return NSAttributedString(string: text, attributes: [NSForegroundColorAttributeName: appearance.textColor, NSFontAttributeName: appearance.textFont])
}

