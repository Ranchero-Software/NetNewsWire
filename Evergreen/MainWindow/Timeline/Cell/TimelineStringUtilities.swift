//
//  TimelineStringUtilities.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data
import RSParser

// TODO: Don’t make all this at top level.

private var truncatedFeedNameCache = [String: String]()
private let truncatedTitleCache = NSMutableDictionary()
private let normalizedTextCache = NSMutableDictionary()
private let textCache = NSMutableDictionary()
private let summaryCache = NSMutableDictionary()

func timelineEmptyCaches() {
	
	truncatedFeedNameCache = [String: String]()
	truncatedTitleCache.removeAllObjects()
	normalizedTextCache.removeAllObjects()
	textCache.removeAllObjects()
	summaryCache.removeAllObjects()
}

func timelineTruncatedFeedName(_ feedName: String) -> String {

	if let cachedFeedName = truncatedFeedNameCache[feedName] {
		return cachedFeedName
	}

	let maxFeedNameLength = 100
	if feedName.count < maxFeedNameLength {
		truncatedFeedNameCache[feedName] = feedName
		return feedName
	}

	let s = (feedName as NSString).substring(to: maxFeedNameLength)
	truncatedFeedNameCache[feedName] = s
	return s
}

func timelineTruncatedTitle(_ article: Article) -> String {

	guard let title = article.title else {
		return ""
	}

	if let cachedTitle = truncatedTitleCache[title] as? String {
		return cachedTitle
	}

	var s = title.replacingOccurrences(of: "\n", with: "")
	s = s.replacingOccurrences(of: "\r", with: "")
	s = s.replacingOccurrences(of: "\t", with: "")
	s = s.replacingOccurrences(of: "↦", with: "")
	s = s.rs_stringByTrimmingWhitespace()
	
	let maxLength = 1000
	if s.count < maxLength {
		truncatedTitleCache[title] = s
		return s
	}

	s = (s as NSString).substring(to: maxLength)
	truncatedTitleCache[title] = s
	return s
}

func timelineTruncatedSummary(_ article: Article) -> String {
	
	return timelineSummaryForArticle(article)
}

func timelineNormalizedText(_ text: String) -> String {

	if text.isEmpty {
		return ""
	}
	if let cachedText = normalizedTextCache[text] as? String {
		return cachedText
	}

	var s = (text as NSString).rs_stringByTrimmingWhitespace()
	s = s.rs_stringWithCollapsedWhitespace()

	let result = s as String
	normalizedTextCache[text] = result
	return result
}

func timelineNormalizedTextTruncated(_ text: String) -> String {

	if text.isEmpty {
		return ""
	}

	if let cachedText = textCache[text] as? String {
		return cachedText
	}

	var s: NSString = (text as NSString).rsparser_stringByDecodingHTMLEntities() as NSString
	s = s.rs_stringByTrimmingWhitespace() as NSString
	s = s.rs_stringWithCollapsedWhitespace() as NSString

	let maxLength = 512
	if s.length > maxLength {
		s = s.substring(to: maxLength) as NSString
	}

	textCache[text] = String(s)
	return s as String
}


func timelineSummaryForArticle(_ article: Article) -> String {

	guard let body = article.body else {
		return ""
	}

	if let cachedBody = summaryCache[body] as? String {
		return cachedBody
	}

	var s = body.rs_string(byStrippingHTML: 300)
	s = timelineNormalizedText(s)
	if s == "Comments" { // Hacker News.
		s = ""
	}
	summaryCache[body] = s
	return s
}

private let dateFormatter: DateFormatter = {
	
	let formatter = DateFormatter()
	formatter.dateStyle = .medium
	formatter.timeStyle = .none
	return formatter
}()

private let timeFormatter: DateFormatter = {
	
	let formatter = DateFormatter()
	formatter.dateStyle = .none
	formatter.timeStyle = .short
	return formatter
}()

private var token: Int = 0

func timelineDateString(_ date: Date) -> String {
	
	if NSCalendar.rs_dateIsToday(date) {
		return timeFormatter.string(from: date)
	}
	
	return dateFormatter.string(from: date)
}

