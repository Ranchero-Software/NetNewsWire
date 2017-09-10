//
//  ParsedFeed.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedFeed {

	public let type: FeedType
	public let title: String?
	public let homePageURL: String?
	public let feedURL: String?
	public let feedDescription: String?
	public let nextURL: String?
	public let iconURL: String?
	public let faviconURL: String?
	public let authors: [ParsedAuthor]?
	public let expired: Bool
	public let hubs: Set<ParsedHub>?
	public let items: Set<ParsedItem>

	init(type: FeedType, title: String?, homePageURL: String?, feedURL: String?, feedDescription: String?, nextURL: String?, iconURL: String?, faviconURL: String?, authors: [ParsedAuthor]?, expired: Bool, hubs: Set<ParsedHub>?, items: Set<ParsedItem>) {

		self.type = type
		self.title = title
		self.homePageURL = homePageURL
		self.feedURL = feedURL
		self.feedDescription = feedDescription
		self.nextURL = nextURL
		self.iconURL = iconURL
		self.faviconURL = faviconURL
		self.authors = authors
		self.expired = expired
		self.hubs = hubs
		self.items = items
	}
}

