//
//  Article.swift
//  Data
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct Article: Hashable {

	public let articleID: String // Unique database ID (possibly sync service ID)
	public let accountID: String
	public let feedID: String // Likely a URL, but not necessarily
	public let uniqueID: String // Unique per feed (RSS guid, for example)
	public let title: String?
	public let contentHTML: String?
	public let contentText: String?
	public let url: String?
	public let externalURL: String?
	public let summary: String?
	public let imageURL: String?
	public let bannerImageURL: String?
	public let datePublished: Date?
	public let dateModified: Date?
	public let authors: Set<Author>?
	public let tags: Set<String>?
	public let attachments: Set<Attachment>?
	public let accountInfo: AccountInfo?
	public let hashValue: Int

	public init(accountID: String, articleID: String?, feedID: String, uniqueID: String, title: String?, contentHTML: String?, contentText: String?, url: String?, externalURL: String?, summary: String?, imageURL: String?, bannerImageURL: String?, datePublished: Date?, dateModified: Date?, authors: Set<Author>?, tags: Set<String>?, attachments: Set<Attachment>?, accountInfo: AccountInfo?) {
		
		self.accountID = accountID
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
		self.authors = authors
		self.tags = tags
		self.attachments = attachments
		self.accountInfo = accountInfo

		if let articleID = articleID {
			self.articleID = articleID
		}
		else {
			self.articleID = databaseIDWithString("\(feedID) \(uniqueID)")
		}

		self.hashValue = accountID.hashValue ^ self.articleID.hashValue
	}

	public static func ==(lhs: Article, rhs: Article) -> Bool {

		return lhs.hashValue == rhs.hashValue && lhs.articleID == rhs.articleID && lhs.accountID == rhs.accountID && lhs.feedID == rhs.feedID && lhs.uniqueID == rhs.uniqueID && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML && lhs.url == rhs.url && lhs.externalURL == rhs.externalURL && lhs.summary == rhs.summary && lhs.imageURL == rhs.imageURL && lhs.bannerImageURL == rhs.bannerImageURL && lhs.datePublished == rhs.datePublished && lhs.authors == rhs.authors && lhs.tags == rhs.tags && lhs.attachments == rhs.attachments
	}
}


