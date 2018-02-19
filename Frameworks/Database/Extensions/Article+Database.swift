//
//  Article+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data
import RSParser

extension Article {
	
	init(databaseArticle: DatabaseArticle, accountID: String, authors: Set<Author>?, attachments: Set<Attachment>?) {

		self.init(accountID: accountID, articleID: databaseArticle.articleID, feedID: databaseArticle.feedID, uniqueID: databaseArticle.uniqueID, title: databaseArticle.title, contentHTML: databaseArticle.contentHTML, contentText: databaseArticle.contentText, url: databaseArticle.url, externalURL: databaseArticle.externalURL, summary: databaseArticle.summary, imageURL: databaseArticle.imageURL, bannerImageURL: databaseArticle.bannerImageURL, datePublished: databaseArticle.datePublished, dateModified: databaseArticle.dateModified, authors: authors, attachments: attachments, status: databaseArticle.status)
	}

	init(parsedItem: ParsedItem, accountID: String, feedID: String, status: ArticleStatus) {

		let authors = Author.authorsWithParsedAuthors(parsedItem.authors)
		let attachments = Attachment.attachmentsWithParsedAttachments(parsedItem.attachments)

		self.init(accountID: accountID, articleID: parsedItem.syncServiceID, feedID: feedID, uniqueID: parsedItem.uniqueID, title: parsedItem.title, contentHTML: parsedItem.contentHTML, contentText: parsedItem.contentText, url: parsedItem.url, externalURL: parsedItem.externalURL, summary: parsedItem.summary, imageURL: parsedItem.imageURL, bannerImageURL: parsedItem.bannerImageURL, datePublished: parsedItem.datePublished ?? parsedItem.dateModified, dateModified: parsedItem.dateModified, authors: authors, attachments: attachments, status: status)
	}

	private func addPossibleStringChangeWithKeyPath(_ comparisonKeyPath: KeyPath<Article,String?>, _ otherArticle: Article, _ key: String, _ dictionary: NSMutableDictionary) {
		
		if self[keyPath: comparisonKeyPath] != otherArticle[keyPath: comparisonKeyPath] {
			dictionary.addOptionalStringDefaultingEmpty(self[keyPath: comparisonKeyPath], key)
		}
	}
	
	func changesFrom(_ otherArticle: Article) -> NSDictionary? {
		
		if self == otherArticle {
			return nil
		}
		
		let d = NSMutableDictionary()
		if uniqueID != otherArticle.uniqueID {
			// This should be super-rare, if ever.
			if !otherArticle.uniqueID.isEmpty {
				d[DatabaseKey.uniqueID] = otherArticle.uniqueID
			}
		}
		
		addPossibleStringChangeWithKeyPath(\Article.title, otherArticle, DatabaseKey.title, d)
		addPossibleStringChangeWithKeyPath(\Article.contentHTML, otherArticle, DatabaseKey.contentHTML, d)
		addPossibleStringChangeWithKeyPath(\Article.contentText, otherArticle, DatabaseKey.contentText, d)
		addPossibleStringChangeWithKeyPath(\Article.url, otherArticle, DatabaseKey.url, d)
		addPossibleStringChangeWithKeyPath(\Article.externalURL, otherArticle, DatabaseKey.externalURL, d)
		addPossibleStringChangeWithKeyPath(\Article.summary, otherArticle, DatabaseKey.summary, d)
		addPossibleStringChangeWithKeyPath(\Article.imageURL, otherArticle, DatabaseKey.imageURL, d)
		addPossibleStringChangeWithKeyPath(\Article.bannerImageURL, otherArticle, DatabaseKey.bannerImageURL, d)

		// If updated versions of dates are nil, and we have existing dates, keep the existing dates.
		// This is data that’s good to have, and it’s likely that a feed removing dates is doing so in error.
		
		if datePublished != otherArticle.datePublished {
			if let updatedDatePublished = otherArticle.datePublished {
				d[DatabaseKey.datePublished] = updatedDatePublished
			}
		}
		if dateModified != otherArticle.dateModified {
			if let updatedDateModified = otherArticle.dateModified {
				d[DatabaseKey.dateModified] = updatedDateModified
			}
		}
		
		if d.count < 1 {
			return nil
		}
		
		return d
	}

	static func articlesWithParsedItems(_ parsedItems: Set<ParsedItem>, _ accountID: String, _ feedID: String, _ statusesDictionary: [String: ArticleStatus]) -> Set<Article> {
	
		return Set(parsedItems.map{ Article(parsedItem: $0, accountID: accountID, feedID: feedID, status: statusesDictionary[$0.articleID]!) })
	}
	
}

extension Article: DatabaseObject {

	public func databaseDictionary() -> NSDictionary? {

		let d = NSMutableDictionary()

		d[DatabaseKey.articleID] = articleID
		d[DatabaseKey.feedID] = feedID
		d[DatabaseKey.uniqueID] = uniqueID

		d.addOptionalString(title, DatabaseKey.title)
		d.addOptionalString(contentHTML, DatabaseKey.contentHTML)
		d.addOptionalString(contentText, DatabaseKey.contentText)
		d.addOptionalString(url, DatabaseKey.url)
		d.addOptionalString(externalURL, DatabaseKey.externalURL)
		d.addOptionalString(summary, DatabaseKey.summary)
		d.addOptionalString(imageURL, DatabaseKey.imageURL)
		d.addOptionalString(bannerImageURL, DatabaseKey.bannerImageURL)

		d.addOptionalDate(datePublished, DatabaseKey.datePublished)
		d.addOptionalDate(dateModified, DatabaseKey.dateModified)

		return (d.copy() as! NSDictionary)
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

	func databaseDictionaries() -> [NSDictionary]? {

		return self.compactMap { $0.databaseDictionary() }
	}
}

private extension NSMutableDictionary {

	func addOptionalString(_ value: String?, _ key: String) {

		if let value = value {
			self[key] = value
		}
	}

	func addOptionalStringDefaultingEmpty(_ value: String?, _ key: String) {
		
		if let value = value {
			self[key] = value
		}
		else {
			self[key] = ""
		}
	}
	
	func addOptionalDate(_ date: Date?, _ key: String) {

		if let date = date {
			self[key] = date as NSDate
		}
	}
}
