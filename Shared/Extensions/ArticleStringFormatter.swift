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
	private var titleCache = [TitleCacheKey: String]()
	private var attributedTitleCache = [String: NSAttributedString]()
	private var summaryCache = [ArticleCacheKey: String]()

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
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	func truncatedFeedName(_ feedName: String) -> String {
		if let cachedFeedName = feedNameCache[feedName] {
			return cachedFeedName
		}

		let maxFeedNameLength = 100

		// `utf8.count` is O(1); grapheme count <= utf8.count, so
		// this is a conservative-but-correct short-enough check.
		if feedName.utf8.count <= maxFeedNameLength {
			feedNameCache[feedName] = feedName
			return feedName
		}

		// Grapheme-safe truncation, bounded by `maxFeedNameLength`.
		let endIndex = feedName.index(feedName.startIndex, offsetBy: maxFeedNameLength, limitedBy: feedName.endIndex) ?? feedName.endIndex
		let s = String(feedName[..<endIndex])
		feedNameCache[feedName] = s
		return s
	}

	func truncatedTitle(_ article: Article, forHTML: Bool = false) -> String {
		guard let rawTitle = article.title, !rawTitle.isEmpty else {
			return ""
		}

		let cacheKey = TitleCacheKey(title: rawTitle, forHTML: forHTML)
		if let cachedTitle = titleCache[cacheKey] {
			return cachedTitle
		}

		guard let sanitized = Self.sanitizedTitle(rawTitle, forHTML: forHTML) else {
			return ""
		}

		// Replace with " " rather than "" so words don't
		// fuse (`"Part 1\nPart 2"` -> `"Part 1 Part 2"`).
		// The `collapsingWhitespace` call further down removes any doubles.
		var s = sanitized
		if s.rangeOfCharacter(from: Self.titleControlCharacters) != nil {
			s = s.replacingOccurrences(of: "\n", with: " ")
			s = s.replacingOccurrences(of: "\r", with: " ")
			s = s.replacingOccurrences(of: "\t", with: " ")
		}

		if !forHTML {
			s = s.decodingHTMLEntities()
		}

		s = s.collapsingWhitespace

		let maxLength = 1000

		if s.utf8.count <= maxLength {
			titleCache[cacheKey] = s
			return s
		}

		// Grapheme-safe truncation.
		let endIndex = s.index(s.startIndex, offsetBy: maxLength, limitedBy: s.endIndex) ?? s.endIndex
		s = String(s[..<endIndex])
		titleCache[cacheKey] = s
		return s
	}

	func attributedTruncatedTitle(_ article: Article) -> NSAttributedString {
		guard let rawTitle = article.title, !rawTitle.isEmpty else {
			return NSAttributedString()
		}

		if let cached = attributedTitleCache[rawTitle] {
			return cached
		}

		let title = truncatedTitle(article, forHTML: true)
		let attributed = NSAttributedString(simpleHTML: title)
		attributedTitleCache[rawTitle] = attributed
		return attributed
	}

	func truncatedSummary(_ article: Article) -> String {
		guard let body = article.body else {
			return ""
		}

		let key = ArticleCacheKey(articleID: article.articleID, accountID: article.accountID)
		if let cachedBody = summaryCache[key] {
			return cachedBody
		}

		// Strip first, then decode. Strip bounds the input to decode
		// at ~300 characters regardless of body size, and it
		// preserves author intent for entity-encoded tags like
		// `&lt;i&gt;` (decode-then-strip would misread those as
		// real `<i>` tags and drop the text).
		var s = body.strippingHTML(maxCharacters: 300)
		s = s.decodingHTMLEntities()
		if s == "Comments" { // Hacker News.
			s = ""
		}
		summaryCache[key] = s
		return s
	}

	// `dateString` is intentionally uncached: ~97% of dates are
	// unique at per-second precision in a real database, so a cache
	// is a net regression vs calling DateFormatter directly.
	func dateString(_ date: Date) -> String {
		if Calendar.dateIsToday(date) {
			return timeFormatter.string(from: date)
		}
		return dateFormatter.string(from: date)
	}

	/// Sanitize an article title that may contain HTML. Returns nil
	/// iff `title` is nil.
	///
	/// Behavior per (allowed, forHTML) combination:
	/// - allowed tag, forHTML=true: tag preserved (`<b>Bold</b>`).
	/// - allowed tag, forHTML=false: tag dropped, contents kept.
	/// - disallowed tag, forHTML=true: tag escaped as `&lt;...&gt;`.
	/// - disallowed tag, forHTML=false: tag preserved literally
	///   (a later `strippingHTML` pass removes it).
	///
	/// Single pass over UTF-8 bytes. Non-ASCII bytes pass through
	/// unchanged — correct for multi-byte text content.
	nonisolated static func sanitizedTitle(_ title: String?, forHTML: Bool) -> String? {
		guard let title else {
			return nil
		}
		if title.isEmpty {
			return ""
		}

		let utf8 = Array(title.utf8)
		let count = utf8.count
		var out = [UInt8]()
		out.reserveCapacity(count)

		let lt = UInt8(ascii: "<")
		let gt = UInt8(ascii: ">")
		let slash = UInt8(ascii: "/")
		// Pre-encoded `&lt;` / `&gt;` so the escape path doesn't
		// convert String to UTF-8 per tag.
		let ltEntity: [UInt8] = [
			UInt8(ascii: "&"), UInt8(ascii: "l"), UInt8(ascii: "t"), UInt8(ascii: ";")
		]
		let gtEntity: [UInt8] = [
			UInt8(ascii: "&"), UInt8(ascii: "g"), UInt8(ascii: "t"), UInt8(ascii: ";")
		]

		var i = 0
		while i < count {
			let b = utf8[i]
			if b != lt {
				out.append(b)
				i += 1
				continue
			}

			// Scan forward for `>` or end of input.
			var j = i + 1
			while j < count && utf8[j] != gt {
				j += 1
			}

			// Empty tag body — emit nothing, skip the `<`, let the
			// next iteration handle any trailing `>` as literal text.
			let tagStart = i + 1
			let tagEnd = j
			if tagStart == tagEnd {
				i += 1
				continue
			}

			// Normalize: strip ALL slashes, preserve case.
			var normalized = [UInt8]()
			normalized.reserveCapacity(tagEnd - tagStart)
			for k in tagStart..<tagEnd {
				let byte = utf8[k]
				if byte != slash {
					normalized.append(byte)
				}
			}
			let isAllowed = allowedTagsBytes.contains(normalized)

			if isAllowed {
				if forHTML {
					out.append(lt)
					out.append(contentsOf: utf8[tagStart..<tagEnd])
					out.append(gt)
				}
			} else {
				if forHTML {
					out.append(contentsOf: ltEntity)
					out.append(contentsOf: utf8[tagStart..<tagEnd])
					out.append(contentsOf: gtEntity)
				} else {
					out.append(lt)
					out.append(contentsOf: utf8[tagStart..<tagEnd])
					out.append(gt)
				}
			}

			i = (j < count) ? j + 1 : count
		}

		return String(decoding: out, as: UTF8.self)
	}
}

// MARK: - Private

private extension ArticleStringFormatter {

	// Article-identity key for the summary cache. Hashable struct
	// avoids per-lookup String allocation.
	struct ArticleCacheKey: Hashable {
		let articleID: String
		let accountID: String
	}

	// (raw title, forHTML) key. Hit path skips `sanitizedTitle`.
	// Including `forHTML` avoids a collision bug where tag-free
	// titles sanitized identically but produced different output
	// under the two flags.
	struct TitleCacheKey: Hashable {
		let title: String
		let forHTML: Bool
	}

	static let titleControlCharacters = CharacterSet(charactersIn: "\n\r\t")

	// UTF-8 byte arrays so tag-name lookup in `sanitizedTitle` stays
	// byte-level — no String allocation per tag.
	nonisolated static let allowedTagsBytes: Set<[UInt8]> = {
		let names = ["b", "bdi", "bdo", "cite", "code", "del", "dfn", "em",
		             "i", "ins", "kbd", "mark", "q", "s", "samp", "small",
		             "strong", "sub", "sup", "time", "u", "var"]
		return Set(names.map { Array($0.utf8) })
	}()

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		emptyCaches()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		emptyCaches()
	}

	func emptyCaches() {
		feedNameCache.removeAll()
		titleCache.removeAll()
		attributedTitleCache.removeAll()
		summaryCache.removeAll()
	}
}
