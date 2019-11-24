//
//  ArticleStringFormatter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSParser

struct ArticleStringFormatter {

	private static var feedNameCache = [String: String]()
	private static var titleCache = [String: String]()
	private static var summaryCache = [String: String]()

	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()

	private static let timeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return formatter
	}()

	static func emptyCaches() {
		feedNameCache = [String: String]()
		titleCache = [String: String]()
		summaryCache = [String: String]()
	}

	static func truncatedFeedName(_ feedName: String) -> String {
		if let cachedFeedName = feedNameCache[feedName] {
			return cachedFeedName
		}

		let maxFeedNameLength = 100
		if feedName.count < maxFeedNameLength {
			feedNameCache[feedName] = feedName
			return feedName
		}

		let s = (feedName as NSString).substring(to: maxFeedNameLength)
		feedNameCache[feedName] = s
		return s
	}

	static func truncatedTitle(_ article: Article) -> String {
		guard let title = article.title else {
			return ""
		}

		if let cachedTitle = titleCache[title] {
			return cachedTitle
		}

		var s = title.replacingOccurrences(of: "\n", with: "")
		s = s.replacingOccurrences(of: "\r", with: "")
		s = s.replacingOccurrences(of: "\t", with: "")
		s = s.rsparser_stringByDecodingHTMLEntities()
		s = s.rs_stringByTrimmingWhitespace()
		s = s.rs_stringWithCollapsedWhitespace()

		let maxLength = 1000
		if s.count < maxLength {
			titleCache[title] = s
			return s
		}

		s = (s as NSString).substring(to: maxLength)
		titleCache[title] = s
		return s
	}

	static func truncatedSummary(_ article: Article) -> String {
		guard let body = article.body else {
			return ""
		}

		let key = article.articleID + article.accountID
		if let cachedBody = summaryCache[key] {
			return cachedBody
		}
		var s = body.rsparser_stringByDecodingHTMLEntities()
		s = s.rs_string(byStrippingHTML: 250)
		s = s.rs_stringByTrimmingWhitespace()
		s = s.rs_stringWithCollapsedWhitespace()
		if s == "Comments" { // Hacker News.
			s = ""
		}
		summaryCache[key] = s
		return s
	}

	static func dateString(_ date: Date) -> String {
		if NSCalendar.rs_dateIsToday(date) {
			return timeFormatter.string(from: date)
		}
		return dateFormatter.string(from: date)
	}
}

