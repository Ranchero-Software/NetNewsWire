//
//  ArticleImageContentBlocker.swift
//  NetNewsWire
//
//  Applies the same block list the article web view uses (ContentRules.json) to
//  app-side image fetches. Routing article images through the offline cache uses
//  URLSession, which doesn't consult WebKit's WKContentRuleList — so without this,
//  a tracker/ad image WebKit would block could still be fetched (and prefetched)
//  when offline caching is on. This closes that gap by reusing the same rules.
//

import Foundation
import os

@MainActor final class ArticleImageContentBlocker {

	static let shared = ArticleImageContentBlocker()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArticleImageContentBlocker")

	// nonisolated + immutable so it can be matched from any thread (e.g. the Downloader's
	// redirect delegate, which runs off the main actor). NSRegularExpression is Sendable and
	// thread-safe for matching.
	nonisolated private let blockRegex: NSRegularExpression?

	init() {
		blockRegex = Self.compileBlockRegex()
	}

	/// True if `urlString` matches one of the web view's content-blocking rules
	/// (ad/tracker domains), and so should not be fetched or cached.
	nonisolated func isBlocked(_ urlString: String) -> Bool {
		guard let blockRegex else {
			return false
		}
		let range = NSRange(urlString.startIndex..., in: urlString)
		return blockRegex.firstMatch(in: urlString, range: range) != nil
	}
}

private extension ArticleImageContentBlocker {

	/// Load ContentRules.json and combine every `block` rule's `url-filter` into one
	/// alternation regex, so a single match tells us whether a URL is blocked.
	static func compileBlockRegex() -> NSRegularExpression? {
		guard let url = Bundle.main.url(forResource: "ContentRules", withExtension: "json") else {
			logger.warning("ArticleImageContentBlocker: ContentRules.json not found")
			return nil
		}
		do {
			let data = try Data(contentsOf: url)
			let rules = try JSONDecoder().decode([ContentRule].self, from: data)
			let patterns = rules.compactMap { rule -> String? in
				guard rule.action.type == "block", let filter = rule.trigger.urlFilter, !filter.isEmpty else {
					return nil
				}
				return "(?:\(filter))"
			}
			guard !patterns.isEmpty else {
				return nil
			}
			return try NSRegularExpression(pattern: patterns.joined(separator: "|"), options: [.caseInsensitive])
		} catch {
			logger.error("ArticleImageContentBlocker: failed to load rules: \(error.localizedDescription)")
			return nil
		}
	}

	struct ContentRule: Decodable {
		let trigger: Trigger
		let action: Action

		struct Trigger: Decodable {
			let urlFilter: String?
			enum CodingKeys: String, CodingKey {
				case urlFilter = "url-filter"
			}
		}

		struct Action: Decodable {
			let type: String
		}
	}
}
