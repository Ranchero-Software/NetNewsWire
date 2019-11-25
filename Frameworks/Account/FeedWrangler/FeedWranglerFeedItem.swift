//
//  FeedWranglerFeedItem.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-10-16.4//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedWranglerFeedItem: Hashable, Codable {
	
	let feedItemID: Int
	let publishedAt: Int
	let createdAt: Int
	let versionKey: Int
	let updatedAt: Int
	let url: String
	let title: String
	let starred: Bool
	let read: Bool
	let readLater: Bool
	let body: String
	let author: String?
	let feedID: Int
	let feedName: String
	
	var publishedDate: Date {
		get {
			Date(timeIntervalSince1970: Double(publishedAt))
		}
	}
	
	var createdDate: Date {
		get {
			Date(timeIntervalSince1970: Double(createdAt))
		}
	}
	
	var updatedDate: Date {
		get {
			Date(timeIntervalSince1970: Double(updatedAt))
		}
	}
	
	enum CodingKeys: String, CodingKey {
		case feedItemID = "feed_item_id"
		case publishedAt = "published_at"
		case createdAt = "created_at"
		case versionKey = "version_key"
		case updatedAt = "updated_at"
		case url = "url"
		case title = "title"
		case starred = "starred"
		case read = "read"
		case readLater = "read_later"
		case body = "body"
		case author = "author"
		case feedID = "feed_id"
		case feedName = "feed_name"
	}
	
}
