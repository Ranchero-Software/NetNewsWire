//
//  FeedWranglerSubscription.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-10-16.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//
import Foundation
import RSCore
import RSParser

struct FeedWranglerSubscription: Hashable, Codable {
	
	let title: String
	let feedID: Int
	let feedURL: String
	let siteURL: String?
	
	enum CodingKeys: String, CodingKey {
		case title = "title"
		case feedID = "feed_id"
		case feedURL = "feed_url"
		case siteURL = "site_url"
	}
	
}
