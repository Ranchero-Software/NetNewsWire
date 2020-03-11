//
//  NewsBlurArticle.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-10.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

typealias NewsBlurArticleHash = NewsBlurUnreadArticleHashesResponse.ArticleHash

struct NewsBlurUnreadArticleHashesResponse: Decodable {
	let subscriptions: [String: [ArticleHash]]

	struct ArticleHash: Hashable, Codable {
		var hash: String
		var timestamp: Date
	}
}

extension NewsBlurUnreadArticleHashesResponse {
	private enum CodingKeys: String, CodingKey {
		case feeds = "unread_feed_story_hashes"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Parse subscriptions
		var subscriptions: [String: [ArticleHash]] = [:]
		let subscriptionContainer = try container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .feeds)
		try subscriptionContainer.allKeys.forEach { key in
		subscriptions[key.stringValue] = []
		var hashArrayContainer = try subscriptionContainer.nestedUnkeyedContainer(forKey: key)
		while !hashArrayContainer.isAtEnd {
			var hashContainer = try hashArrayContainer.nestedUnkeyedContainer()
			let hash = try hashContainer.decode(String.self)
			let timestamp = try hashContainer.decode(Date.self)
			let articleHash = ArticleHash(hash: hash, timestamp: timestamp)

			subscriptions[key.stringValue]?.append(articleHash)
		}
		}

		self.subscriptions = subscriptions
	}
}
