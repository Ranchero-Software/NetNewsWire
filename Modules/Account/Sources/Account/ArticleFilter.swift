//
//  ArticleFilter.swift
//  Account
//
//  Created on 3/23/26.
//

import Foundation
import Articles

public struct ArticleFilter: Codable, Equatable, Sendable {

	public enum MatchType: String, Codable, Sendable {
		case contains
		case doesNotContain
	}

	public struct MatchFields: OptionSet, Codable, Equatable, Sendable {
		public let rawValue: Int

		public init(rawValue: Int) {
			self.rawValue = rawValue
		}

		public static let tag = MatchFields(rawValue: 1 << 0)
		public static let title = MatchFields(rawValue: 1 << 1)
		public static let content = MatchFields(rawValue: 1 << 2)
		public static let summary = MatchFields(rawValue: 1 << 3)

		public static let all: MatchFields = [.tag, .title, .content, .summary]
	}

	public let keyword: String
	public let matchType: MatchType
	/// Which article fields to match against. Nil means all fields (backwards compatible).
	public let matchFields: MatchFields?

	public init(keyword: String, matchType: MatchType, matchFields: MatchFields? = nil) {
		self.keyword = keyword
		self.matchType = matchType
		self.matchFields = matchFields
	}

	/// Returns true if this filter says the article should be marked as read.
	public func matches(_ article: Article, tags: Set<String>? = nil) -> Bool {
		let keyword = keyword.trimmingCharacters(in: .whitespaces)
		guard !keyword.isEmpty else {
			return false
		}

		let fields = matchFields ?? .all
		let keywordLower = keyword.lowercased()
		var found = false

		if fields.contains(.tag), let tags {
			found = tags.contains { $0.lowercased().contains(keywordLower) }
		}

		if !found, fields.contains(.title), let title = article.title {
			found = title.lowercased().contains(keywordLower)
		}

		if !found, fields.contains(.content) {
			if let contentText = article.contentText {
				found = contentText.lowercased().contains(keywordLower)
			} else if let contentHTML = article.contentHTML {
				found = contentHTML.lowercased().contains(keywordLower)
			}
		}

		if !found, fields.contains(.summary), let summary = article.summary {
			found = summary.lowercased().contains(keywordLower)
		}

		if !found, fields.contains(.content), let authors = article.authors {
			for author in authors {
				if let name = author.name, name.lowercased().contains(keywordLower) {
					found = true
					break
				}
			}
		}

		switch matchType {
		case .contains:
			return found
		case .doesNotContain:
			return !found
		}
	}
}

public extension Array where Element == ArticleFilter {

	private static var decoder: JSONDecoder { JSONDecoder() }
	private static var encoder: JSONEncoder { JSONEncoder() }

	/// Returns true if any filter in the array matches the article.
	func anyFilterMatches(_ article: Article, tags: Set<String>? = nil) -> Bool {
		contains { $0.matches(article, tags: tags) }
	}

	static func filtersWithJSON(_ jsonString: String) -> [ArticleFilter]? {
		guard let data = jsonString.data(using: .utf8) else {
			return nil
		}
		return try? decoder.decode([ArticleFilter].self, from: data)
	}

	func json() -> String? {
		guard let data = try? Self.encoder.encode(self) else {
			return nil
		}
		return String(data: data, encoding: .utf8)
	}
}
