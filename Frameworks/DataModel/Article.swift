//
//  Article.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class Article: Hashable {

	weak var account: Account?
	let feedID: String
	let articleID: String //Calculated: unique per account

	var uniqueID: String //guid: unique per feed
	var title: String?
	var contentHTML: String?
	var contentText: String?
	var url: String?
	var externalURL: String?
	var summary: String?
	var imageURL: String?
	var bannerImageURL: String?
	var datePublished: Date?
	var dateModified: Date?
	var authors: [Authors]?
	var tags: [String]?
	var attachments: [Attachment]?
	var status: ArticleStatus?

	public var accountInfo: [String: Any]? //If account needs to store more data

	var feed: Feed? {
		get {
			return account?.existingFeed(with: feedID)
		}
	}

	init(account: Account, feedID: String, uniqueID: String, title: String?, contentHTML: String?, contentText: String?, url: String?, externalURL: String?, summary: String?, imageURL: String?, bannerImageURL: String?, datePublished: Date?, dateModified: Date?, authors: [Authors]?, tags: [String]?, attachments: [Attachment]?) {

		self.account = account
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
		self.dateArrived = dateArrived
		self.authors = authors
		self.tags = tags
		self.attachments = attachments

		self.hashValue = account.hashValue + feedID.hashValue + uniqueID.hashValue
	}

	public class func ==(lhs: Article, rhs: Article) -> Bool {

		return lhs === rhs
	}
}

public extension Article {

	public var logicalDatePublished: Date? {
		get {
			return (datePublished ?? dateModified) && status?.dateArrived
		}
	}
}
