//
//  NewsBlurFeed.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-09.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

typealias NewsBlurFeed = NewsBlurFeedsResponse.Feed

struct NewsBlurFeedsResponse: Decodable {
	let feeds: [Feed]
	let folders: [Folder]

	struct Feed: Hashable, Codable {
		let title: String
		let feedId: Int
		let feedURL: String
		let siteURL: String?
		let favicon: String?
	}

	struct Folder: Hashable, Codable {
		let name: String
		let feedIds: [Int]
	}
}

extension NewsBlurFeedsResponse {
	private enum CodingKeys: String, CodingKey {
		case feeds = "feeds"
		case folders = "flat_folders"
		// TODO: flat_folders_with_inactive
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Parse feeds
		var feeds: [Feed] = []
		let feedContainer = try container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .feeds)
		try feedContainer.allKeys.forEach { key in
			let subscription = try feedContainer.decode(Feed.self, forKey: key)
			feeds.append(subscription)
		}

		// Parse folders
		var folders: [Folder] = []
		let folderContainer = try container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .folders)
		try folderContainer.allKeys.forEach { key in
			let subscriptionIds = try folderContainer.decode([Int].self, forKey: key)
			let folder = Folder(name: key.stringValue, feedIds: subscriptionIds)

			folders.append(folder)
		}

		self.feeds = feeds
		self.folders = folders
	}
}

extension NewsBlurFeedsResponse.Feed {
	private enum CodingKeys: String, CodingKey {
		case title = "feed_title"
		case feedId = "id"
		case feedURL = "feed_address"
		case siteURL = "feed_link"
		case favicon = "favicon_url"
	}
}
