//
//  FeedlyFeedParser.swift
//  Account
//
//  Created by Kiel Gillard on 29/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyFeedParser: Sendable {

	public let feed: FeedlyFeed

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()
	
	public var title: String? {
		return rightToLeftTextSantizer.sanitize(feed.title) ?? ""
	}
	
	public var feedID: String {
		return feed.id
	}
	
	public var url: String {
		let resource = FeedlyFeedResourceID(id: feed.id)
		return resource.url
	}
	
	public var homePageURL: String? {
		return feed.website
	}

	public init(feed: FeedlyFeed) {
	
		self.feed = feed
	}
}
