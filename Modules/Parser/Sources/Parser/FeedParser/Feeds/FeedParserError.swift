//
//  FeedParserError.swift
//  RSParser
//
//  Created by Brent Simmons on 6/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedParserError: Error, Sendable {

	public enum FeedParserErrorType: Sendable {

		case rssChannelNotFound
		case rssItemsNotFound
		case jsonFeedVersionNotFound
		case jsonFeedItemsNotFound
		case jsonFeedTitleNotFound
		case invalidJSON
	}

	public let errorType: FeedParserErrorType

	public init(_ errorType: FeedParserErrorType) {

		self.errorType = errorType
	}
}
