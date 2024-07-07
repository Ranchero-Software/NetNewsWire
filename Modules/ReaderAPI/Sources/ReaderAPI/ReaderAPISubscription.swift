//
//  ReaderAPISubscription.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import FoundationExtras

/*

	{
		"numResults":0,
		"error": "Already subscribed! https://inessential.com/xml/rss.xml
	}

*/

public struct ReaderAPIQuickAddResult: Codable, Sendable {

	public let numResults: Int
	public let error: String?
	public let streamID: String?

	enum CodingKeys: String, CodingKey {
		case numResults = "numResults"
		case error = "error"
		case streamID = "streamId"
	}
}

public struct ReaderAPISubscriptionContainer: Codable, Sendable {
	
	public let subscriptions: [ReaderAPISubscription]

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
public struct ReaderAPISubscription: Codable, Sendable {
	
	public let feedID: String
	public let name: String?
	public let categories: [ReaderAPICategory]
	public let feedURL: String?
	public let homePageURL: String?
	public let iconURL: String?

	enum CodingKeys: String, CodingKey {
		case feedID = "id"
		case name = "title"
		case categories = "categories"
		case feedURL = "url"
		case homePageURL = "htmlUrl"
		case iconURL = "iconUrl"
	}

	public var url: String {
		if let feedURL = feedURL {
			return feedURL
		} else {
			return feedID.stripping(prefix: "feed/")
		}
	}
}

public struct ReaderAPICategory: Codable, Sendable {

	public let categoryID: String
	public let categoryLabel: String
	
	enum CodingKeys: String, CodingKey {
		case categoryID = "id"
		case categoryLabel = "label"
	}
}

public struct ReaderAPICreateSubscription: Codable, Sendable {

	public let feedURL: String

	enum CodingKeys: String, CodingKey {
		case feedURL = "feed_url"
	}
}

public struct ReaderAPISubscriptionChoice: Codable, Sendable {

	public let name: String?
	public let url: String

	enum CodingKeys: String, CodingKey {
		case name = "title"
		case url = "feed_url"
	}
}
