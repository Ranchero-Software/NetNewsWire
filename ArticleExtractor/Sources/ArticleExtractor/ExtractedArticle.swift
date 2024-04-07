//
//  ExtractedArticle.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

public struct ExtractedArticle: Codable, Equatable, Sendable {

	public let title: String?
	public let author: String?
	public let datePublished: String?
	public let dek: String?
	public let leadImageURL: String?
	public let content: String?
	public let nextPageURL: String?
	public let url: String?
	public let domain: String?
	public let excerpt: String?
	public let wordCount: Int?
	public let direction: String?
	public let totalPages: Int?
	public let renderedPages: Int?

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
