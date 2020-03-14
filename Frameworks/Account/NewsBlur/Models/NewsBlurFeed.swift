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
typealias NewsBlurFolder = NewsBlurFeedsResponse.Folder

struct NewsBlurFeedsResponse: Decodable {
	let feeds: [Feed]
	let folders: [Folder]

	struct Feed: Hashable, Codable {
		let name: String
		let feedID: Int
		let feedURL: String
		let homepageURL: String?
		let faviconURL: String?
	}

	struct Folder: Hashable, Codable {
		let name: String
		let feedIDs: [Int]
	}
}

struct NewsBlurFolderRelationship: Codable {
	let folderName: String
	let feedID: Int
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

		// Skip "everything" folder
		for key in folderContainer.allKeys where key.stringValue != " " {
			let subscriptionIds = try folderContainer.decode([Int].self, forKey: key)
			let folder = Folder(name: key.stringValue, feedIDs: subscriptionIds)

			folders.append(folder)
		}

		self.feeds = feeds
		self.folders = folders
	}
}

extension NewsBlurFeedsResponse.Feed {
	private enum CodingKeys: String, CodingKey {
		case name = "feed_title"
		case feedID = "id"
		case feedURL = "feed_address"
		case homepageURL = "feed_link"
		case faviconURL = "favicon_url"
	}
}

extension NewsBlurFeedsResponse.Folder {
	var asRelationships: [NewsBlurFolderRelationship] {
		return feedIDs.map { NewsBlurFolderRelationship(folderName: name, feedID: $0) }
	}
}
