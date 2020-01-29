//
//  FeedlyFeedParser.swift
//  Account
//
//  Created by Kiel Gillard on 29/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyFeedParser {
	let feed: FeedlyFeed

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()
	
	var title: String? {
		return rightToLeftTextSantizer.sanitize(feed.title) ?? ""
	}
	
	var webFeedID: String {
		return feed.id
	}
	
	var url: String {
		let resource = FeedlyFeedResourceId(id: feed.id)
		return resource.url
	}
	
	var homePageURL: String? {
		return feed.website
	}
}
