//
//  ReaderAPIFeed.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

/*

	{
		"numResults":0,
		"error": "Already subscribed! https://inessential.com/xml/rss.xml
	}

*/

struct ReaderAPIQuickAddResult: Codable {
	let numResults: Int
	let error: String?
	let streamId: String?
	
	enum CodingKeys: String, CodingKey {
		case numResults = "numResults"
		case error = "error"
		case streamId = "streamId"
	}
}

struct ReaderAPISubscriptionContainer: Codable {
	let subscriptions: [ReaderAPISubscription]
	
	enum CodingKeys: String, CodingKey {
		case subscriptions = "subscriptions"
	}
}

/*
{
	"id": "feed/1",
	"title": "Questionable Content",
	"categories": [
	{
		"id": "user/-/label/Comics",
		"label": "Comics"
	}
	],
	"url": "http://www.questionablecontent.net/QCRSS.xml",
	"htmlUrl": "http://www.questionablecontent.net",
	"iconUrl": "https://rss.confusticate.com/f.php?24decabc"
}

*/
struct ReaderAPISubscription: Codable {
	let feedID: String
	let name: String?
	let categories: [ReaderAPICategory]
	let url: String
	let homePageURL: String?
	let iconURL: String?

	enum CodingKeys: String, CodingKey {
		case feedID = "id"
		case name = "title"
		case categories = "categories"
		case url = "url"
		case homePageURL = "htmlUrl"
		case iconURL = "iconUrl"
	}

}

struct ReaderAPICategory: Codable {
	let categoryId: String
	let categoryLabel: String
	
	enum CodingKeys: String, CodingKey {
		case categoryId = "id"
		case categoryLabel = "label"
	}
}

struct ReaderAPICreateSubscription: Codable {
	let feedURL: String
	enum CodingKeys: String, CodingKey {
		case feedURL = "feed_url"
	}
}

struct ReaderAPISubscriptionChoice: Codable {
	
	let name: String?
	let url: String
	
	enum CodingKeys: String, CodingKey {
		case name = "title"
		case url = "feed_url"
	}
	
}
