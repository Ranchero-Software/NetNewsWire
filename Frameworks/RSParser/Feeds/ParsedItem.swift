//
//  ParsedItem.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedItem: Hashable {

	public let uniqueID: String
	public let feedURL: String
	public let url: String?
	public let externalURL: String?
	public let title: String?
	public let contentHTML: String?
	public let contentText: String?
	public let summary: String?
	public let imageURL: String?
	public let bannerImageURL: String?
	public let datePublished: Date?
	public let dateModified: Date?
	public let authors: [ParsedAuthor]?
	public let tags: [String]?
	public let attachments: [ParsedAttachment]?
	public let hashValue: Int
	
	init(uniqueID: String, feedURL: String, url: String?, externalURL: String?, title: String?, contentHTML: String?, contentText: String?, summary: String?, imageURL: String?, bannerImageURL: String?, datePublished: Date?, dateModified: Date?, authors: [ParsedAuthor]?, tags: [String]?, attachments: [ParsedAttachment]?) {

		self.uniqueID = uniqueID
		self.feedURL = feedURL
		self.url = url
		self.externalURL = externalURL
		self.title = title
		self.contentHTML = contentHTML
		self.contentText = contentText
		self.summary = summary
		self.imageURL = imageURL
		self.bannerImageURL = bannerImageURL
		self.datePublished = datePublished
		self.dateModified = dateModified
		self.authors = authors
		self.tags = tags
		self.attachments = attachments
		self.hashValue = uniqueID.hashValue
	}
	
	public static func ==(lhs: ParsedItem, rhs: ParsedItem) -> Bool {
		
		return lhs.hashValue == rhs.hashValue && lhs.uniqueID == rhs.uniqueID && lhs.feedURL == rhs.feedURL
	}
}

