//
//  FeedbinFeed.swift
//  Account
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

struct FeedbinFeed {

	// https://github.com/feedbin/feedbin-api/blob/master/content/feeds.md
	//
	//	"id": 525,
	//	"created_at": "2013-03-12T11:30:25.209432Z",
	//	"feed_id": 47,
	//	"title": "Daring Fireball",
	//	"feed_url": "http://daringfireball.net/index.xml",
	//	"site_url": "http://daringfireball.net/"

	let subscriptionID: Int
	let feedID: Int
	let creationDate: Date?
	let name: String?
	let url: String
	let homePageURL: String?

	struct Key {
		static let subscriptionID = "id"
		static let feedID = "feed_id"
		static let creationDate = "created_at"
		static let name = "title"
		static let url = "feed_url"
		static let homePageURL = "site_url"
	}

	init?(dictionary: JSONDictionary) {

		guard let subscriptionID = dictionary[Key.subscriptionID] as? Int else {
			return nil
		}
		guard let feedID = dictionary[Key.feedID] as? Int else {
			return nil
		}
		guard let url = dictionary[Key.url] as? String else {
			return nil
		}

		self.subscriptionID = subscriptionID
		self.feedID = feedID
		self.url = url

		if let creationDateString = dictionary[Key.creationDate] as? String {
			self.creationDate = RSDateWithString(creationDateString)
		}
		else {
			self.creationDate = nil
		}

		self.name = dictionary[Key.name] as? String
		self.homePageURL = dictionary[Key.homePageURL] as? String
	}

	static func feeds(with array: JSONArray) -> [FeedbinFeed]? {

		let subs = array.compactMap { FeedbinFeed(dictionary: $0) }
		return subs.isEmpty ? nil : subs
	}
}
