//
//  Article.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias ArticleSetBlock = (Set<Article>) -> Void

public struct Article: Hashable {

	public let articleID: String // Unique database ID (possibly sync service ID)
	public let accountID: String
	public let webFeedID: String // Likely a URL, but not necessarily
	public let uniqueID: String // Unique per feed (RSS guid, for example)
	public let title: String?
	public let contentHTML: String?
	public let contentText: String?
	public let url: String?
	public let externalURL: String?
	public let summary: String?
	public let imageURL: String?
	public let datePublished: Date?
	public let dateModified: Date?
	public let authors: Set<Author>?
	public let status: ArticleStatus

	public init(accountID: String, articleID: String?, webFeedID: String, uniqueID: String, title: String?, contentHTML: String?, contentText: String?, url: String?, externalURL: String?, summary: String?, imageURL: String?, datePublished: Date?, dateModified: Date?, authors: Set<Author>?, status: ArticleStatus) {
		self.accountID = accountID
		self.webFeedID = webFeedID
		self.uniqueID = uniqueID
		self.title = title
		self.contentHTML = contentHTML
		self.contentText = contentText
		self.url = url
		self.externalURL = externalURL
		self.summary = summary
		self.imageURL = imageURL
		self.datePublished = datePublished
		self.dateModified = dateModified
		self.authors = authors
		self.status = status
		
		if let articleID = articleID {
			self.articleID = articleID
		}
		else {
			self.articleID = Article.calculatedArticleID(webFeedID: webFeedID, uniqueID: uniqueID)
		}
	}

	public static func calculatedArticleID(webFeedID: String, uniqueID: String) -> String {
		return databaseIDWithString("\(webFeedID) \(uniqueID)")
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(articleID)
	}
}

public extension Set where Element == Article {
	
	func articleIDs() -> Set<String> {
		return Set<String>(map { $0.articleID })
	}

	func unreadArticles() -> Set<Article> {
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
