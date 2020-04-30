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

	// MARK: - Equatable

	static public func ==(lhs: Article, rhs: Article) -> Bool {
		guard lhs.articleID == rhs.articleID else {
			print("*********** miss matched articleID")
			return false
		}
		guard lhs.accountID == rhs.accountID else {
			print("*********** miss matched accountID")
			return false
		}
		guard lhs.webFeedID == rhs.webFeedID else {
			print("*********** miss matched webFeedID")
			return false
		}
		guard lhs.uniqueID == rhs.uniqueID else {
			print("*********** miss matched uniqueID")
			return false
		}
		guard lhs.title == rhs.title else {
			print("*********** miss matched title")
			return false
		}
		guard lhs.contentHTML == rhs.contentHTML else {
			print("*********** miss matched contentHTML")
			return false
		}
		guard lhs.contentText == rhs.contentText else {
			print("*********** miss matched contentText")
			return false
		}
		guard lhs.url == rhs.url else {
			print("*********** miss matched url")
			return false
		}
		guard lhs.externalURL == rhs.externalURL else {
			print("*********** miss matched externalURL")
			return false
		}
		guard lhs.summary == rhs.summary else {
			print("*********** miss matched summary")
			return false
		}
		guard lhs.imageURL == rhs.imageURL else {
			print("*********** miss matched imageURL")
			return false
		}
		guard lhs.datePublished == rhs.datePublished else {
			print("*********** miss matched datePublished")
			return false
		}
		guard lhs.dateModified == rhs.dateModified else {
			print("*********** miss matched dateModified")
			return false
		}
		guard lhs.authors == rhs.authors else {
			print("*********** miss matched authors")
			return false
		}
		return true
//		return lhs.articleID == rhs.articleID && lhs.accountID == rhs.accountID && lhs.webFeedID == rhs.webFeedID && lhs.uniqueID == rhs.uniqueID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs.contentText == rhs.contentText && lhs.url == rhs.url && lhs.externalURL == rhs.externalURL && lhs.summary == rhs.summary && lhs.imageURL == rhs.imageURL && lhs.datePublished == rhs.datePublished && lhs.dateModified == rhs.dateModified && lhs.authors == rhs.authors
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
