//
//  LocalArticle.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import DataModel

public final class LocalArticle: NSObject, Article {

	public let account: Account?
	public let feedID: String
	public let articleID: String
	public var status: ArticleStatus!

	public var guid: String?
	public var title: String?
	private var _body: String?
	fileprivate var bodyData: Data?
	
	public var body: String? {
		get {
			if _body == nil, let d = bodyData {
//				print(title)
				if let s = NSString(data: d, encoding: String.Encoding.utf8.rawValue) as String? {
					_body = s
					bodyData = nil
				}
			}
			return _body
		}
		set {
			_body = newValue
		}
	}
	
	public var link: String?
	public var permalink: String?
	public var author: String?

	public var datePublished: Date?
	public var dateModified: Date?

	private let _hash: Int
	
	public override var hashValue: Int {
		get {
			return _hash
		}
	}
	
	public init(account: Account, feedID: String, articleID: String) {

		self.account = account
		self.feedID = feedID
		self.articleID = articleID
		self._hash = articleID.hashValue
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		
		if let otherArticle = object as? LocalArticle {
			return otherArticle === self
		}
		return false
	}
	
//	static public func ==(lhs: LocalArticle, rhs: LocalArticle) -> Bool {
//		
//		if lhs === rhs {
//			return true
//		}
//		
//		return lhs.hashValue == rhs.hashValue && lhs.articleID == rhs.articleID && lhs.feedID == rhs.feedID && lhs.guid == rhs.guid && lhs.title == rhs.title && lhs.body == rhs.body && lhs.link == rhs.link && lhs.permalink == rhs.permalink && lhs.author == rhs.author && lhs.datePublished == rhs.datePublished && lhs.status == rhs.status;
//	}

}


// MARK: LocalDatabase support

import RSCore
import RSDatabase
import RSXML

// Database columns *and* value keys.

let articleIDKey = "articleID"
private let articleFeedIDKey = "feedID"
private let articleGuidKey = "guid"
private let articleTitleKey = "title"
private let articleBodyKey = "body"
private let articleDatePublishedKey = "datePublished"
private let articleDateModifiedKey = "dateModified"
private let articleLinkKey = "link"
private let articlePermalinkKey = "permalink"
private let articleAuthorKey = "author"

private let mergeablePropertyNames = [articleGuidKey, articleTitleKey, articleBodyKey, articleDatePublishedKey, articleDateModifiedKey, articleLinkKey, articlePermalinkKey, articleAuthorKey]

public extension LocalArticle {

	convenience init(account: Account, feedID: String, parsedArticle: RSParsedArticle) {

		self.init(account: account, feedID: feedID, articleID: parsedArticle.articleID)
		
		self.guid = parsedArticle.guid
		self.title = parsedArticle.title
		self.body = parsedArticle.body
		self.datePublished = parsedArticle.datePublished
		self.dateModified = parsedArticle.dateModified
		self.link = parsedArticle.link
		self.permalink = parsedArticle.permalink
		self.author = parsedArticle.author
	}

	private enum ColumnIndex: Int {
		case articleID = 0, feedID, guid, title, body, datePublished, dateModified, link, permalink, author
	}
	
	convenience init?(account: Account, row: FMResultSet) {

		guard let articleID = row.string(forColumnIndex: Int32(ColumnIndex.articleID.rawValue)), let feedID = row.string(forColumnIndex: Int32(ColumnIndex.feedID.rawValue)) else {
			return nil
		}

		self.init(account: account, feedID: feedID, articleID: articleID)
		
		self.guid = row.string(forColumnIndex: Int32(ColumnIndex.guid.rawValue))
		self.title = row.string(forColumnIndex: Int32(ColumnIndex.title.rawValue))
		self.bodyData = row.data(forColumnIndex: Int32(ColumnIndex.body.rawValue))
		self.datePublished = row.date(forColumnIndex: Int32(ColumnIndex.datePublished.rawValue))
		self.dateModified = row.date(forColumnIndex: Int32(ColumnIndex.dateModified.rawValue))
		self.link = row.string(forColumnIndex: Int32(ColumnIndex.link.rawValue))
		self.permalink = row.string(forColumnIndex: Int32(ColumnIndex.permalink.rawValue))
		self.author = row.string(forColumnIndex: Int32(ColumnIndex.author.rawValue))
	}

	var databaseDictionary: NSDictionary {
		get {
			return createDatabaseDictionary()
		}
	}

	func updateWithParsedArticle(_ parsedArticle: RSParsedArticle) -> NSDictionary? {

		let d: NSDictionary = rs_mergeValues(withObjectReturningChanges: parsedArticle, propertyNames: mergeablePropertyNames) as NSDictionary
		if d.count < 1 {
			return nil
		}

		let databaseDictionary: NSMutableDictionary = d.mutableCopy() as! NSMutableDictionary
		databaseDictionary[articleIDKey] = articleIDKey
		return databaseDictionary
	}

	private func createDatabaseDictionary() -> NSDictionary {

		// Includes only non-nil values.

		let d = NSMutableDictionary()

		d[articleIDKey] = articleID
		d[articleFeedIDKey] = feedID
		
		if let guid = self.guid {
			d[articleGuidKey] = guid
		}
		if let title = self.title {
			d[articleTitleKey] = title
		}
		if let body = self.body {
			d[articleBodyKey] = body
		}
		if let datePublished = self.datePublished {
			d[articleDatePublishedKey] = datePublished
		}
		if let dateModified = self.dateModified {
			d[articleDateModifiedKey] = dateModified
		}
		if let link = self.link {
			d[articleLinkKey] = link
		}
		if let permalink = self.permalink {
			d[articlePermalinkKey] = permalink
		}
		if let author = self.author {
			d[articleAuthorKey] = author
		}

		return d
	}
}
