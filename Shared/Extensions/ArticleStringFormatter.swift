//
//  ArticleStringFormatter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSCore
import RSParser

@MainActor final class ArticleStringFormatter {
	static let shared = ArticleStringFormatter()

	private var feedNameCache = [String: String]()
	private var titleCache = [String: String]()
	private var summaryCache = [String: String]()

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

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		feedNameCache.removeAll()
		titleCache.removeAll()
		summaryCache.removeAll()
	}

	func truncatedFeedName(_ feedName: String) -> String {
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

	func truncatedTitle(_ article: Article, forHTML: Bool = false) -> String {
		guard let title = article.sanitizedTitle(forHTML: forHTML) else {
			return ""
		}

		if let cachedTitle = titleCache[title] {
			return cachedTitle
		}

		var s = title.replacingOccurrences(of: "\n", with: "")
		s = s.replacingOccurrences(of: "\r", with: "")
		s = s.replacingOccurrences(of: "\t", with: "")

		if !forHTML {
			s = s.rsparser_stringByDecodingHTMLEntities()
		}

		s = s.trimmingWhitespace
		s = s.collapsingWhitespace

		let maxLength = 1000
		if s.count < maxLength {
			titleCache[title] = s
			return s
		}

		s = (s as NSString).substring(to: maxLength)
		titleCache[title] = s
		return s
	}

	func attributedTruncatedTitle(_ article: Article) -> NSAttributedString {
		let title = truncatedTitle(article, forHTML: true)
		let attributed = NSAttributedString(html: title)
		return attributed
	}

	func truncatedSummary(_ article: Article) -> String {
		guard let body = article.body else {
			return ""
		}

		let key = article.articleID + article.accountID
		if let cachedBody = summaryCache[key] {
			return cachedBody
		}
		var s = body.rsparser_stringByDecodingHTMLEntities()
		s = s.strippingHTML(maxCharacters: 300)
		if s == "Comments" { // Hacker News.
			s = ""
		}
		summaryCache[key] = s
		return s
	}

	func dateString(_ date: Date) -> String {
		if Calendar.dateIsToday(date) {
			return timeFormatter.string(from: date)
		}
		return dateFormatter.string(from: date)
	}
}
