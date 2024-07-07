//
//  NewsBlurStoryHash.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-13.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser

public typealias NewsBlurStoryHash = NewsBlurStoryHashesResponse.StoryHash

public struct NewsBlurStoryHashesResponse: Decodable, Sendable {

	public typealias StoryHashDictionary = [String: [StoryHash]]

	public var unread: [StoryHash]?
	public var starred: [StoryHash]?

	public struct StoryHash: Hashable, Codable, Sendable {

		public var hash: String
		public var timestamp: Date

		public init(hash: String, timestamp: Date) {

			self.hash = hash
			self.timestamp = timestamp
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(hash)
		}
	}
}

extension NewsBlurStoryHashesResponse {
	
	private enum CodingKeys: String, CodingKey {
		case unread = "unread_feed_story_hashes"
		case starred = "starred_story_hashes"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Parse unread
		if let unreadContainer = try? container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .unread) {
			let storyHashes = try NewsBlurStoryHashesResponse.extractHashes(container: unreadContainer)
			self.unread = storyHashes.values.flatMap { $0 }
		}

		// Parse starred
		if let starredContainer = try? container.nestedUnkeyedContainer(forKey: .starred) {
			self.starred = try NewsBlurStoryHashesResponse.extractArray(container: starredContainer)
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

	static func extractArray(container: UnkeyedDecodingContainer) throws -> [StoryHash] {
		var hashes: [StoryHash] = []
		var hashArrayContainer = container
		while !hashArrayContainer.isAtEnd {
			var hashContainer = try hashArrayContainer.nestedUnkeyedContainer()
			let hash = try hashContainer.decode(String.self)
			let timestamp = try (hashContainer.decode(String.self) as NSString).doubleValue
			let storyHash = StoryHash(hash: hash, timestamp: Date(timeIntervalSince1970: timestamp))

			hashes.append(storyHash)
		}

		return hashes
	}
}
