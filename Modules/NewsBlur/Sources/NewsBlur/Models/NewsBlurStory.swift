//
//  NewsBlurStory.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-10.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

public typealias NewsBlurStory = NewsBlurStoriesResponse.Story

public struct NewsBlurStoriesResponse: Decodable, Sendable {
	public let stories: [Story]

	public struct Story: Decodable, Sendable {
		public let storyID: String
		public let feedID: Int
		public let title: String?
		public let url: String?
		public let authorName: String?
		public let contentHTML: String?
		/// The secure (proxied) copy of the first image, else the image itself.
		public var imageURL: String? {
			guard let firstImageURL = imageURLs?.first else {
				return nil
			}
			return secureImageURLs?[firstImageURL] ?? firstImageURL
		}
		public var thumbnailURL: String? {
			guard let firstImageURL = imageURLs?.first else {
				return nil
			}
			return secureImageThumbnails?[firstImageURL]
		}
		public var tags: [String]?
		public var datePublished: Date? {
			let interval = (publishedTimestamp as NSString).doubleValue
			return Date(timeIntervalSince1970: interval)
		}

		/// In story order. The secure dictionaries are keyed by these URLs.
		private var imageURLs: [String]?
		private var secureImageURLs: [String: String]?
		private var secureImageThumbnails: [String: String]?
		private var publishedTimestamp: String
	}
}

extension NewsBlurStoriesResponse {
	private enum CodingKeys: String, CodingKey {
		case stories
	}
}

extension NewsBlurStoriesResponse.Story {
	private enum CodingKeys: String, CodingKey {
		case storyID = "story_hash"
		case feedID = "story_feed_id"
		case title = "story_title"
		case url = "story_permalink"
		case authorName = "story_authors"
		case contentHTML = "story_content"
		case imageURLs = "image_urls"
		case secureImageURLs = "secure_image_urls"
		case secureImageThumbnails = "secure_image_thumbnails"
		case tags = "story_tags"
		case publishedTimestamp = "story_timestamp"
	}
}
