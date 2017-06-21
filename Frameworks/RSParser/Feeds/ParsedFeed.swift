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
	public let hubs: [ParsedHub]?
	public let items: [ParsedItem]
}
