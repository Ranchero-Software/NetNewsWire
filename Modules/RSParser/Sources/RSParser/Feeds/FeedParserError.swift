//
//  FeedParserError.swift
//  RSParser
//
//  Created by Brent Simmons on 6/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum FeedParserError: Error, Sendable {
	case rssChannelNotFound
	case rssItemsNotFound
	case jsonFeedVersionNotFound
	case jsonFeedItemsNotFound
	case jsonFeedTitleNotFound
	case invalidJSON
}
