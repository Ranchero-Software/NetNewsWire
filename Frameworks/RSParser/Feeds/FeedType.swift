//
//  FeedType.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum FeedType {
	case rss
	case atom
	case jsonFeed
	case rssInJSON
	case unknown
	case notAFeed
}
