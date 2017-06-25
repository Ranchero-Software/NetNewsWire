//
//  FeedParserError.swift
//  RSParser
//
//  Created by Brent Simmons on 6/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedParserError: Error {

	public enum FeedParserErrorType {

		case rssChannelNotFound
		case rssItemsNotFound

	}

	public let errorType: FeedParserErrorType

	public init(_ errorType: FeedParserErrorType) {

		self.errorType = errorType
	}
}
