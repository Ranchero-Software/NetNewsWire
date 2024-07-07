//
//  NewsBlurStory.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-10.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser

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
		public var imageURL: String? {
			return imageURLs?.first?.value
		}
		public var tags: [String]?
		public var datePublished: Date? {
			let interval = (publishedTimestamp as NSString).doubleValue
			return Date(timeIntervalSince1970: interval)
		}

		private var imageURLs: [String: String]?
		private var publishedTimestamp: String
	}
}

extension NewsBlurStoriesResponse {

	private enum CodingKeys: String, CodingKey {
		case stories = "stories"
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
		case imageURLs = "secure_image_urls"
		case tags = "story_tags"
		case publishedTimestamp = "story_timestamp"
	}
}
