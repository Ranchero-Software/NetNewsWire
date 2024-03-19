//
//  Article.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias ArticleSetBlock = (Set<Article>) -> Void

public struct Article: Hashable, Sendable {

	public let articleID: String // Unique database ID (possibly sync service ID)
	public let accountID: String
	public let feedID: String // Likely a URL, but not necessarily
	public let uniqueID: String // Unique per feed (RSS guid, for example)
	public let title: String?
	public let contentHTML: String?
	public let contentText: String?
	public let rawLink: String? // We store raw source value, but use computed url or link other than where raw value required.
    public let rawExternalLink: String? // We store raw source value, but use computed externalURL or externalLink other than where raw value required.
	public let summary: String?
	public let rawImageLink: String? // We store raw source value, but use computed imageURL or imageLink other than where raw value required.
	public let datePublished: Date?
	public let dateModified: Date?
	public let authors: Set<Author>?
	public let status: ArticleStatus

	public init(accountID: String, articleID: String?, feedID: String, uniqueID: String, title: String?, contentHTML: String?, contentText: String?, url: String?, externalURL: String?, summary: String?, imageURL: String?, datePublished: Date?, dateModified: Date?, authors: Set<Author>?, status: ArticleStatus) {
		self.accountID = accountID
		self.feedID = feedID
		self.uniqueID = uniqueID
		self.title = title
		self.contentHTML = contentHTML
		self.contentText = contentText
		self.rawLink = url
		self.rawExternalLink = externalURL
		self.summary = summary
		self.rawImageLink = imageURL
		self.datePublished = datePublished
		self.dateModified = dateModified
		self.authors = authors
		self.status = status
		
		if let articleID = articleID {
			self.articleID = articleID
		}
		else {
			self.articleID = Article.calculatedArticleID(feedID: feedID, uniqueID: uniqueID)
		}
	}

	public static func calculatedArticleID(feedID: String, uniqueID: String) -> String {
		return DatabaseIDCache.shared.databaseIDWithString("\(feedID) \(uniqueID)")
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(articleID)
	}

	// MARK: - Equatable

	static public func ==(lhs: Article, rhs: Article) -> Bool {
		return lhs.articleID == rhs.articleID && lhs.accountID == rhs.accountID && lhs.feedID == rhs.feedID && lhs.uniqueID == rhs.uniqueID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs.contentText == rhs.contentText && lhs.rawLink == rhs.rawLink && lhs.rawExternalLink == rhs.rawExternalLink && lhs.summary == rhs.summary && lhs.rawImageLink == rhs.rawImageLink && lhs.datePublished == rhs.datePublished && lhs.dateModified == rhs.dateModified && lhs.authors == rhs.authors
	}
}

public extension Set where Element == Article {
	
	func articleIDs() -> Set<String> {
		return Set<String>(map { $0.articleID })
	}

	@MainActor func unreadArticles() -> Set<Article> {
		let articles = self.filter { !$0.status.read }
		return Set(articles)
	}

	func contains(accountID: String, articleID: String) -> Bool {
		return contains(where: { $0.accountID == accountID && $0.articleID == articleID})
	}
	
}

public extension Array where Element == Article {
	
	func articleIDs() -> [String] {
		return map { $0.articleID }
	}
}

public extension Article {
	private static let allowedTags: Set = ["b", "bdi", "bdo", "cite", "code", "del", "dfn", "em", "i", "ins", "kbd", "mark", "q", "s", "samp", "small", "strong", "sub", "sup", "time", "u", "var"]

	func sanitizedTitle(forHTML: Bool = true) -> String? {
		guard let title = title else { return nil }

		let scanner = Scanner(string: title)
		scanner.charactersToBeSkipped = nil
		var result = ""
		result.reserveCapacity(title.count)

		while !scanner.isAtEnd {
			if let text = scanner.scanUpToString("<") {
				result.append(text)
			}

			if let _ = scanner.scanString("<") {
				// All the allowed tags currently don't allow attributes
				if let tag = scanner.scanUpToString(">") {
					if Self.allowedTags.contains(tag.replacingOccurrences(of: "/", with: "")) {
						forHTML ? result.append("<\(tag)>") : result.append("")
					} else {
						forHTML ? result.append("&lt;\(tag)&gt;") : result.append("<\(tag)>")
					}

					let _ = scanner.scanString(">")
				}
			}
		}

		return result
	}

}
