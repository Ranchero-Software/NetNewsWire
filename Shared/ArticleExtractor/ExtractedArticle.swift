//
//  ExtractedArticle.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

struct ExtractedArticle: Codable, Equatable {

	let title: String?
	let author: String?
	let datePublished: String?
	let dek: String?
	let leadImageURL: String?
	let content: String?
	let nextPageURL: String?
	let url: String?
	let domain: String?
	let excerpt: String?
	let wordCount: Int?
	let direction: String?
	let totalPages: Int?
	let renderedPages: Int?
	
	enum CodingKeys: String, CodingKey {
		case title = "title"
		case author = "author"
		case datePublished = "date_published"
		case dek = "dek"
		case leadImageURL = "lead_image_url"
		case content = "content"
		case nextPageURL = "next_page_url"
		case url = "url"
		case domain = "domain"
		case excerpt = "excerpt"
		case wordCount = "word_count"
		case direction = "direction"
		case totalPages = "total_pages"
		case renderedPages = "rendered_pages"
	}
	
}
