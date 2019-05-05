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

struct FeedbinFeed: Codable {

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

	enum CodingKeys: String, CodingKey {
		case subscriptionID = "id"
		case feedID = "feed_id"
		case creationDate = "created_at"
		case name = "title"
		case url = "feed_url"
		case homePageURL = "site_url"
	}

}
