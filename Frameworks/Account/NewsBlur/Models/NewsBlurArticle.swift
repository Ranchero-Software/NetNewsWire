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

typealias NewsBlurArticle = NewsBlurArticlesResponse.Article

struct NewsBlurArticlesResponse: Decodable {
	let articles: [Article]

	struct Article: Decodable {
		let articleId: String
		let feedId: Int
		let title: String?
		let url: String?
		let authorName: String?
		let contentHTML: String?
		let datePublished: Date
	}
}

extension NewsBlurArticlesResponse {
	private enum CodingKeys: String, CodingKey {
		case articles = "stories"
	}
}

extension NewsBlurArticlesResponse.Article {
	private enum CodingKeys: String, CodingKey {
		case articleId = "story_hash"
		case feedId = "story_feed_id"
		case title = "story_title"
		case url = "story_permalink"
		case authorName = "story_authors"
		case contentHTML = "story_content"
		case datePublished = "story_date"
	}
}
