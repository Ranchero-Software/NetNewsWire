//
//  FeedbinArticle.swift
//  Account
//
//  Created by Brent Simmons on 12/11/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

struct FeedbinEntry: Codable {

	let articleID: Int
	let feedID: Int
	let title: String?
	let url: String?
	let authorName: String?
	let contentHTML: String?
	let contentDiffHTML: String?
	let summary: String?
	let datePublished: Date?
	let dateArrived: Date?

	enum CodingKeys: String, CodingKey {
		case articleID = "id"
		case feedID = "feed_id"
		case title = "title"
		case url = "url"
		case authorName = "author"
		case contentHTML = "content"
		case contentDiffHTML = "content_diff"
		case summary = "summary"
		case datePublished = "published"
		case dateArrived = "created_at"
	}

}
