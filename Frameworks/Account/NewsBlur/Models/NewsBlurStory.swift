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

typealias NewsBlurStory = NewsBlurStoriesResponse.Story

struct NewsBlurStoriesResponse: Decodable {
	let stories: [Story]

	struct Story: Decodable {
		let storyID: String
		let feedID: Int
		let title: String?
		let url: String?
		let authorName: String?
		let contentHTML: String?
		var imageURL: String? {
			return imageURLs?.first?.value
		}
		var tags: [String]?
		var datePublished: Date? {
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
