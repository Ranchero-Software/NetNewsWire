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
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		emptyCaches()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		emptyCaches()
	}

	private func emptyCaches() {
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
			s = s.decodingHTMLEntities()
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
		var s = body.decodingHTMLEntities()
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

	// MARK: - Title sanitization

	// Stored as UTF-8 byte arrays so tag-name lookup during
	// `sanitizedTitle` can be done byte-level without converting the
	// scanned tag back to a String per call.
	nonisolated private static let allowedTagsBytes: Set<[UInt8]> = {
		let names = ["b", "bdi", "bdo", "cite", "code", "del", "dfn", "em",
		             "i", "ins", "kbd", "mark", "q", "s", "samp", "small",
		             "strong", "sub", "sup", "time", "u", "var"]
		return Set(names.map { Array($0.utf8) })
	}()

	/// Sanitize an article title, which may contain HTML, into
	/// either HTML-safe rendering (when `forHTML: true`) or a
	/// plain-text form suitable for further processing (when
	/// `forHTML: false`). Returns nil iff `title` is nil.
	///
	/// Behavior for each of the four (allowed, forHTML) combinations:
	/// - allowed tag, forHTML=true: tag preserved as-is (`<b>Bold</b>`).
	/// - allowed tag, forHTML=false: tag dropped, contents kept.
	/// - disallowed tag, forHTML=true: tag escaped as `&lt;...&gt;` text.
	/// - disallowed tag, forHTML=false: tag preserved literally (the
	///   caller — typically `strippingHTML` — removes it later).
	///
	/// Implementation notes: single pass over UTF-8 bytes. `<`, `>`,
	/// `/`, and ASCII tag characters are all single-byte; non-ASCII
	/// bytes pass through as-is (correct for multi-byte text
	/// content). The previous Scanner-based implementation went
	/// through Foundation for every tag boundary, with per-tag
	/// `scanUpToString` bridges and String allocations. On the cold
	/// scroll path, that cost compounded across every unique article
	/// title.
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
		// `&lt;` and `&gt;` as byte arrays — pre-encoded so the
		// escape path doesn't pay a String-to-UTF8 conversion per tag.
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

			// Found `<`. Scan forward for matching `>` or end of input.
			var j = i + 1
			while j < count && utf8[j] != gt {
				j += 1
			}

			// Tag body is utf8[i+1..<j]. Empty-body edge case matches
			// the Scanner quirk: `scanUpToString(">")` returns nil
			// when no characters are scanned (either at end of
			// string, or `>` is immediately next). In both cases we
			// emit no tag and don't consume the `>` — the outer loop
			// handles any trailing `>` as literal text on the next
			// iteration.
			let tagStart = i + 1
			let tagEnd = j
			if tagStart == tagEnd {
				i += 1 // past the `<` only
				continue
			}

			// Build a normalized tag name for lookup. The original
			// used `tag.replacingOccurrences(of: "/", with: "")` —
			// ALL slashes removed, case preserved. Match that.
			var normalized = [UInt8]()
			normalized.reserveCapacity(tagEnd - tagStart)
			for k in tagStart..<tagEnd {
				let byte = utf8[k]
				if byte != slash {
					normalized.append(byte)
				}
			}
			let isAllowed = Self.allowedTagsBytes.contains(normalized)

			if isAllowed {
				if forHTML {
					// Preserve tag literally (slashes included).
					out.append(lt)
					out.append(contentsOf: utf8[tagStart..<tagEnd])
					out.append(gt)
				}
				// forHTML=false: tag dropped entirely.
			} else {
				if forHTML {
					// Escape as `&lt;tag&gt;` so the reader sees it
					// as text rather than an unknown element.
					out.append(contentsOf: ltEntity)
					out.append(contentsOf: utf8[tagStart..<tagEnd])
					out.append(contentsOf: gtEntity)
				} else {
					// Preserve literally for a later HTML-stripping
					// pass (e.g. `strippingHTML`) to remove.
					out.append(lt)
					out.append(contentsOf: utf8[tagStart..<tagEnd])
					out.append(gt)
				}
			}

			// Advance past `>` if one was found, else to end of input.
			i = (j < count) ? j + 1 : count
		}

		return String(decoding: out, as: UTF8.self)
	}
}
