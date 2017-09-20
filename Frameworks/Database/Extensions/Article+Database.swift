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
	
//	init?(row: FMResultSet, accountID: String, authors: Set<Author>? = nil, attachments: Set<Attachment>? = nil, tags: Set<String>? = nil, status: ArticleStatus) {
//		
//		guard let feedID = row.string(forColumn: DatabaseKey.feedID) else {
//			return nil
//		}
//		guard let uniqueID = row.string(forColumn: DatabaseKey.uniqueID) else {
//			return nil
//		}
//		
//		let articleID = row.string(forColumn: DatabaseKey.articleID)!
//		let title = row.string(forColumn: DatabaseKey.title)
//		let contentHTML = row.string(forColumn: DatabaseKey.contentHTML)
//		let contentText = row.string(forColumn: DatabaseKey.contentText)
//		let url = row.string(forColumn: DatabaseKey.url)
//		let externalURL = row.string(forColumn: DatabaseKey.externalURL)
//		let summary = row.string(forColumn: DatabaseKey.summary)
//		let imageURL = row.string(forColumn: DatabaseKey.imageURL)
//		let bannerImageURL = row.string(forColumn: DatabaseKey.bannerImageURL)
//		let datePublished = row.date(forColumn: DatabaseKey.datePublished)
//		let dateModified = row.date(forColumn: DatabaseKey.dateModified)
//		let accountInfo: AccountInfo? = nil // TODO
//
//		self.init(accountID: accountID, articleID: articleID, feedID: feedID, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: tags, attachments: attachments, accountInfo: accountInfo, status: status)
//	}

	init?(dictionary: [String: Any], accountID: String, status: ArticleStatus, authors: Set<Author>?, attachments: Set<Attachment>?, tags: Set<String>?) {

		guard let articleID = dictionary[DatabaseKey.articleID] as? String, let feedID = dictionary[DatabaseKey.feedID] as? String, let uniqueID = dictionary[DatabaseKey.uniqueID] as? String else {
			return nil
		}

		let title = dictionary[DatabaseKey.title] as? String
		let contentHTML = dictionary[DatabaseKey.contentHTML] as? String
		let contentText = dictionary[DatabaseKey.contentText] as? String
		let url = dictionary[DatabaseKey.url] as? String
		let externalURL = dictionary[DatabaseKey.externalURL] as? String
		let summary = dictionary[DatabaseKey.summary] as? String
		let imageURL = dictionary[DatabaseKey.imageURL] as? String
		let bannerImageURL = dictionary[DatabaseKey.bannerImageURL] as? String
		let datePublished = dictionary[DatabaseKey.datePublished] as? Date
		let dateModified = dictionary[DatabaseKey.dateModified] as? Date
		let accountInfo: AccountInfo? = nil // TODO

		self.init(accountID: accountID, articleID: articleID, feedID: feedID, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: tags, attachments: attachments, accountInfo: accountInfo, status: status)
	}

	init(parsedItem: ParsedItem, accountID: String, feedID: String, status: ArticleStatus) {

		let authors = Author.authorsWithParsedAuthors(parsedItem.authors)
		let attachments = Attachment.attachmentsWithParsedAttachments(parsedItem.attachments)

		self.init(accountID: accountID, articleID: parsedItem.syncServiceID, feedID: feedID, uniqueID: parsedItem.uniqueID, title: parsedItem.title, contentHTML: parsedItem.contentHTML, contentText: parsedItem.contentText, url: parsedItem.url, externalURL: parsedItem.externalURL, summary: parsedItem.summary, imageURL: parsedItem.imageURL, bannerImageURL: parsedItem.bannerImageURL, datePublished: parsedItem.datePublished, dateModified: parsedItem.dateModified, authors: authors, tags: parsedItem.tags, attachments: attachments, accountInfo: nil, status: status)
	}

//	func articleByAttaching(_ authors: Set<Author>?, _ attachments: Set<Attachment>?, _ tags: Set<String>?) -> Article {
//
//		if authors == nil && attachments == nil && tags == nil {
//			return self
//		}
//
//		return Article(accountID: accountID, articleID: articleID, feedID: feedID, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: tags, attachments: attachments, accountInfo: accountInfo, status: status)
//	}

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
		
		// TODO: accountInfo
		
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

		// TODO: accountInfo

		return (d.copy() as! NSDictionary)
	}
	
	public var databaseID: String {
		get {
			return articleID
		}
	}
}

extension Set where Element == Article {

	func articleIDs() -> Set<String> {

		return Set<String>(map { $0.databaseID })
	}

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

		return self.flatMap { $0.databaseDictionary() }
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
