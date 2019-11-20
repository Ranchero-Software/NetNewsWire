//
//  DatabaseArticle.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/21/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

// Intermediate representation of an Article. Doesn’t include related objects.
// Used by ArticlesTable as part of fetching articles.

struct DatabaseArticle: Hashable {

	let articleID: String
	let webFeedID: String
	let uniqueID: String
	let title: String?
	let contentHTML: String?
	let contentText: String?
	let url: String?
	let externalURL: String?
	let summary: String?
	let imageURL: String?
	let bannerImageURL: String?
	let datePublished: Date?
	let dateModified: Date?
	let status: ArticleStatus

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(articleID)
	}
}

extension Set where Element == DatabaseArticle {

	func articleIDs() -> Set<String> {
		return Set<String>(map { $0.articleID })
	}
}
