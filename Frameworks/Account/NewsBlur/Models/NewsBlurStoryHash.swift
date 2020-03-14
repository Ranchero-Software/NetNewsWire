//
//  NewsBlurStoryHash.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-13.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

typealias NewsBlurStoryHash = NewsBlurStoryHashesResponse.StoryHash

struct NewsBlurStoryHashesResponse: Decodable {
	typealias StoryHashDictionary = [String: [StoryHash]]

	var unread: StoryHashDictionary?
	var starred: StoryHashDictionary?

	struct StoryHash: Hashable, Codable {
		var hash: String
		var timestamp: Date
	}
}

extension NewsBlurStoryHashesResponse {
	private enum CodingKeys: String, CodingKey {
		case unread = "unread_feed_story_hashes"
		case starred = "starred_story_hashes"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Parse unread
		if let unreadContainer = try? container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .unread) {
			self.unread = try NewsBlurStoryHashesResponse.extractHashes(container: unreadContainer)
		}

		// Parse starred
		if let starredContainer = try? container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .starred) {
			self.starred = try NewsBlurStoryHashesResponse.extractHashes(container: starredContainer)
		}
	}

	static func extractHashes<Key>(container: KeyedDecodingContainer<Key>) throws -> StoryHashDictionary where Key: CodingKey {
		var dict: StoryHashDictionary = [:]
		for key in container.allKeys {
			dict[key.stringValue] = []
			var hashArrayContainer = try container.nestedUnkeyedContainer(forKey: key)
			while !hashArrayContainer.isAtEnd {
				var hashContainer = try hashArrayContainer.nestedUnkeyedContainer()
				let hash = try hashContainer.decode(String.self)
				let timestamp = try hashContainer.decode(Date.self)
				let storyHash = StoryHash(hash: hash, timestamp: timestamp)

				dict[key.stringValue]?.append(storyHash)
			}
		}

		return dict
	}
}
