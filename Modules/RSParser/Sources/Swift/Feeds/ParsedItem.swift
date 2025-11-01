//
//  ParsedItem.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSMarkdown

public struct ParsedItem: Hashable {

	public let syncServiceID: String? //Nil when not syncing
	public let uniqueID: String //RSS guid, for instance; may be calculated
	public let feedURL: String
	public let url: String?
	public let externalURL: String?
	public let title: String?
	public let language: String?
	public let contentHTML: String?
	public let contentText: String?
	public let markdown: String?
	public let summary: String?
	public let imageURL: String?
	public let bannerImageURL: String?
	public let datePublished: Date?
	public let dateModified: Date?
	public let authors: Set<ParsedAuthor>?
	public let tags: Set<String>?
	public let attachments: Set<ParsedAttachment>?
	
	public init(syncServiceID: String?, uniqueID: String, feedURL: String, url: String?, externalURL: String?, title: String?,
				language: String?, contentHTML: String?, contentText: String?, markdown: String?, summary: String?, imageURL: String?,
				bannerImageURL: String?,datePublished: Date?, dateModified: Date?, authors: Set<ParsedAuthor>?,
				tags: Set<String>?, attachments: Set<ParsedAttachment>?) {
		
		self.syncServiceID = syncServiceID
		self.uniqueID = uniqueID
		self.feedURL = feedURL
		self.url = url
		self.externalURL = externalURL
		self.title = title
		self.language = language
		self.contentText = contentText
		self.markdown = markdown
		self.summary = summary
		self.imageURL = imageURL
		self.bannerImageURL = bannerImageURL
		self.datePublished = datePublished
		self.dateModified = dateModified
		self.authors = authors
		self.tags = tags
		self.attachments = attachments

		// Render Markdown when present, else use contentHTML
		if let markdown {
			self.contentHTML = RSMarkdown.markdownToHTML(markdown)
		} else {
			self.contentHTML = contentHTML
		}
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		if let syncServiceID = syncServiceID {
			hasher.combine(syncServiceID)
		}
		else {
			hasher.combine(uniqueID)
			hasher.combine(feedURL)
		}
	}
}

