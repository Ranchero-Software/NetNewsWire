//
//  NewsBlurUnreadStory.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-13.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

typealias NewsBlurStoryHash = NewsBlurUnreadStoryHashesResponse.StoryHash

struct NewsBlurUnreadStoryHashesResponse: Decodable {
	let feeds: [String: [StoryHash]]

	struct StoryHash: Hashable, Codable {
		var hash: String
		var timestamp: Date
	}
}

extension NewsBlurUnreadStoryHashesResponse {
	private enum CodingKeys: String, CodingKey {
		case feeds = "unread_feed_story_hashes"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Parse feeds
		var feeds: [String: [StoryHash]] = [:]
		let feedContainer = try container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .feeds)
		try feedContainer.allKeys.forEach { key in
			feeds[key.stringValue] = []
			var hashArrayContainer = try feedContainer.nestedUnkeyedContainer(forKey: key)
			while !hashArrayContainer.isAtEnd {
				var hashContainer = try hashArrayContainer.nestedUnkeyedContainer()
				let hash = try hashContainer.decode(String.self)
				let timestamp = try hashContainer.decode(Date.self)
				let storyHash = StoryHash(hash: hash, timestamp: timestamp)

				feeds[key.stringValue]?.append(storyHash)
			}
		}

		self.feeds = feeds
	}
}
