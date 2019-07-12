//
//  Article+Database.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Articles
import RSParser

extension Article {
	
	init(databaseArticle: DatabaseArticle, accountID: String, authors: Set<Author>?, attachments: Set<Attachment>?) {
		self.init(accountID: accountID, articleID: databaseArticle.articleID, feedID: databaseArticle.feedID, uniqueID: databaseArticle.uniqueID, title: databaseArticle.title, contentHTML: databaseArticle.contentHTML, contentText: databaseArticle.contentText, url: databaseArticle.url, externalURL: databaseArticle.externalURL, summary: databaseArticle.summary, imageURL: databaseArticle.imageURL, bannerImageURL: databaseArticle.bannerImageURL, datePublished: databaseArticle.datePublished, dateModified: databaseArticle.dateModified, authors: authors, attachments: attachments, status: databaseArticle.status)
	}

	init(parsedItem: ParsedItem, maximumDateAllowed: Date, accountID: String, feedID: String, status: ArticleStatus) {
		let authors = Author.authorsWithParsedAuthors(parsedItem.authors)
		let attachments = Attachment.attachmentsWithParsedAttachments(parsedItem.attachments)

		// Deal with future datePublished and dateModified dates.
		var datePublished = parsedItem.datePublished
		if datePublished == nil {
			datePublished = parsedItem.dateModified
		}
		if datePublished != nil, datePublished! > maximumDateAllowed {
			datePublished = nil
		}

		var dateModified = parsedItem.dateModified
		if dateModified != nil, dateModified! > maximumDateAllowed {
			dateModified = nil
		}

		self.init(accountID: accountID, articleID: parsedItem.syncServiceID, feedID: feedID, uniqueID: parsedItem.uniqueID, title: parsedItem.title, contentHTML: parsedItem.contentHTML, contentText: parsedItem.contentText, url: parsedItem.url, externalURL: parsedItem.externalURL, summary: parsedItem.summary, imageURL: parsedItem.imageURL, bannerImageURL: parsedItem.bannerImageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, attachments: attachments, status: status)
	}

	private func addPossibleStringChangeWithKeyPath(_ comparisonKeyPath: KeyPath<Article,String?>, _ otherArticle: Article, _ key: String, _ dictionary: inout DatabaseDictionary) {
		if self[keyPath: comparisonKeyPath] != otherArticle[keyPath: comparisonKeyPath] {
			dictionary[key] = self[keyPath: comparisonKeyPath] ?? ""
		}
	}
	
	func changesFrom(_ existingArticle: Article) -> DatabaseDictionary? {
		if self == existingArticle {
			return nil
		}
		
		var d = DatabaseDictionary()
		if uniqueID != existingArticle.uniqueID {
			d[DatabaseKey.uniqueID] = uniqueID
		}

		addPossibleStringChangeWithKeyPath(\Article.title, existingArticle, DatabaseKey.title, &d)
		addPossibleStringChangeWithKeyPath(\Article.contentHTML, existingArticle, DatabaseKey.contentHTML, &d)
		addPossibleStringChangeWithKeyPath(\Article.contentText, existingArticle, DatabaseKey.contentText, &d)
		addPossibleStringChangeWithKeyPath(\Article.url, existingArticle, DatabaseKey.url, &d)
		addPossibleStringChangeWithKeyPath(\Article.externalURL, existingArticle, DatabaseKey.externalURL, &d)
		addPossibleStringChangeWithKeyPath(\Article.summary, existingArticle, DatabaseKey.summary, &d)
		addPossibleStringChangeWithKeyPath(\Article.imageURL, existingArticle, DatabaseKey.imageURL, &d)
		addPossibleStringChangeWithKeyPath(\Article.bannerImageURL, existingArticle, DatabaseKey.bannerImageURL, &d)

		// If updated versions of dates are nil, and we have existing dates, keep the existing dates.
		// This is data that’s good to have, and it’s likely that a feed removing dates is doing so in error.
		if datePublished != existingArticle.datePublished {
			if let updatedDatePublished = datePublished {
				d[DatabaseKey.datePublished] = updatedDatePublished
			}
		}
		if dateModified != existingArticle.dateModified {
			if let updatedDateModified = dateModified {
				d[DatabaseKey.dateModified] = updatedDateModified
			}
		}

		return d.count < 1 ? nil : d
	}

	static func articlesWithParsedItems(_ parsedItems: Set<ParsedItem>, _ accountID: String, _ feedID: String, _ statusesDictionary: [String: ArticleStatus]) -> Set<Article> {
		let maximumDateAllowed = Date().addingTimeInterval(60 * 60 * 24) // Allow dates up to about 24 hours ahead of now
		return Set(parsedItems.map{ Article(parsedItem: $0, maximumDateAllowed: maximumDateAllowed, accountID: accountID, feedID: feedID, status: statusesDictionary[$0.articleID]!) })
	}
	
}

extension Article: DatabaseObject {

	public func databaseDictionary() -> DatabaseDictionary? {
		var d = DatabaseDictionary()

		d[DatabaseKey.articleID] = articleID
		d[DatabaseKey.feedID] = feedID
		d[DatabaseKey.uniqueID] = uniqueID

		if let title = title {
			d[DatabaseKey.title] = title
		}
		if let contentHTML = contentHTML {
			d[DatabaseKey.contentHTML] = contentHTML
		}
		if let contentText = contentText {
			d[DatabaseKey.contentText] = contentText
		}
		if let url = url {
			d[DatabaseKey.url] = url
		}
		if let externalURL = externalURL {
			d[DatabaseKey.externalURL] = externalURL
		}
		if let summary = summary {
			d[DatabaseKey.summary] = summary
		}
		if let imageURL = imageURL {
			d[DatabaseKey.imageURL] = imageURL
		}
		if let bannerImageURL = bannerImageURL {
			d[DatabaseKey.bannerImageURL] = bannerImageURL
		}
		if let datePublished = datePublished {
			d[DatabaseKey.datePublished] = datePublished
		}
		if let dateModified = dateModified {
			d[DatabaseKey.dateModified] = dateModified
		}
		return d
	}
	
	public var databaseID: String {
		return articleID
	}

	public func relatedObjectsWithName(_ name: String) -> [DatabaseObject]? {
		switch name {
		case RelationshipName.authors:
			return databaseObjectArray(with: authors)
		case RelationshipName.attachments:
			return databaseObjectArray(with: attachments)
		default:
			return nil
		}
	}

	private func databaseObjectArray<T: DatabaseObject>(with objects: Set<T>?) -> [DatabaseObject]? {
		guard let objects = objects else {
			return nil
		}
		return Array(objects)
	}
}

extension Set where Element == Article {

	func statuses() -> Set<ArticleStatus> {
		return Set<ArticleStatus>(map { $0.status })
	}
	
	func dictionary() -> [String: Article] {
		var d = [String: Article]()
		for article in self {
			d[article.articleID] = article
		}
		return d
	}

	func databaseObjects() -> [DatabaseObject] {
		return self.map{ $0 as DatabaseObject }
	}

	func databaseDictionaries() -> [DatabaseDictionary]? {
		return self.compactMap { $0.databaseDictionary() }
	}
}
