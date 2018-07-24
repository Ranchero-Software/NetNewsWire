//
//  DatabaseArticle.swift
//  Database
//
//  Created by Brent Simmons on 9/21/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

// Intermediate representation of an Article. Doesn’t include related objects.
// Used by ArticlesTable as part of fetching articles.

struct DatabaseArticle: Hashable {

	let articleID: String
	let feedID: String
	let uniqueID: String
	let title: String?
	let contentHTML: String?
	let contentText: String?
	let url: String?
	let externalURL: String?
	let summary: String?
	let imageURL: String?
	let bannerImageURL: String?
	let datePublished: Date?
	let dateModified: Date?
	let status: ArticleStatus
	let hashValue: Int

	init(articleID: String, feedID: String, uniqueID: String, title: String?, contentHTML: String?, contentText: String?, url: String?, externalURL: String?, summary: String?, imageURL: String?, bannerImageURL: String?, datePublished: Date?, dateModified: Date?, status: ArticleStatus) {

		self.articleID = articleID
		self.feedID = feedID
		self.uniqueID = uniqueID
		self.title = title
		self.contentHTML = contentHTML
		self.contentText = contentText
		self.url = url
		self.externalURL = externalURL
		self.summary = summary
		self.imageURL = imageURL
		self.bannerImageURL = bannerImageURL
		self.datePublished = datePublished
		self.dateModified = dateModified
		self.status = status
		self.hashValue = articleID.hashValue
	}

	static func ==(lhs: DatabaseArticle, rhs: DatabaseArticle) -> Bool {

		return lhs.hashValue == rhs.hashValue && lhs.articleID == rhs.articleID && lhs.feedID == rhs.feedID && lhs.uniqueID == rhs.uniqueID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs.contentText == rhs.contentText && lhs.url == rhs.url && lhs.externalURL == rhs.externalURL && lhs.summary == rhs.summary && lhs.imageURL == rhs.imageURL && lhs.bannerImageURL == rhs.bannerImageURL && lhs.datePublished == rhs.datePublished && lhs.dateModified == rhs.dateModified && lhs.status == rhs.status
	}
}


extension Set where Element == DatabaseArticle {

	func articleIDs() -> Set<String> {

		return Set<String>(map { $0.articleID })
	}
}
