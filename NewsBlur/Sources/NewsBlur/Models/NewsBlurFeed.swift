//
//  NewsBlurFeed.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-09.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser

public typealias NewsBlurFolder = NewsBlurFeedsResponse.Folder

public struct NewsBlurFeed: Hashable, Codable, Sendable {

	public let name: String
	public let feedID: Int
	public let feedURL: String
	public let homePageURL: String?
	public let faviconURL: String?

	public func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
	}
}

public struct NewsBlurFeedsResponse: Decodable, Sendable {

	public let feeds: [NewsBlurFeed]
	public let folders: [Folder]

	public struct Folder: Hashable, Codable, Sendable {
		
		public let name: String
		public let feedIDs: [Int]

		public func hash(into hasher: inout Hasher) {
			hasher.combine(name)
		}
	}
}

public struct NewsBlurAddURLResponse: Decodable, Sendable {

	public let feed: NewsBlurFeed?
}

public struct NewsBlurFolderRelationship: Sendable {
	
	public let folderName: String
	public let feedID: Int
}

extension NewsBlurFeed {

	private enum CodingKeys: String, CodingKey {
		case name = "feed_title"
		case feedID = "id"
		case feedURL = "feed_address"
		case homePageURL = "feed_link"
		case faviconURL = "favicon_url"
	}
}

extension NewsBlurFeedsResponse {

	private enum CodingKeys: String, CodingKey {
		case feeds = "feeds"
		case folders = "flat_folders"
		// TODO: flat_folders_with_inactive
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Tricky part: Some feeds listed in `feeds` don't exist in `folders` for some reason
		// They don't show up on both mobile/web app, so let's filter them out
		var visibleFeedIDs: [Int] = []

		// Parse folders
		var folders: [Folder] = []
		let folderContainer = try container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .folders)

		for key in folderContainer.allKeys {
			let feedIDs = try folderContainer.decode([Int].self, forKey: key)
			let folder = Folder(name: key.stringValue, feedIDs: feedIDs)

			folders.append(folder)
			visibleFeedIDs.append(contentsOf: feedIDs)
		}

		// Parse feeds
		var feeds: [NewsBlurFeed] = []
		let feedContainer = try container.nestedContainer(keyedBy: NewsBlurGenericCodingKeys.self, forKey: .feeds)
		for key in feedContainer.allKeys {
			let feed = try feedContainer.decode(NewsBlurFeed.self, forKey: key)
			feeds.append(feed)
		}

		self.feeds = feeds.filter { visibleFeedIDs.contains($0.feedID) }
		self.folders = folders
	}
}

extension NewsBlurFeedsResponse.Folder {
	
	public var asRelationships: [NewsBlurFolderRelationship] {
		return feedIDs.map { NewsBlurFolderRelationship(folderName: name, feedID: $0) }
	}
}
