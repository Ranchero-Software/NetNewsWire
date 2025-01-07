//
//  RSSFeed.swift
//
//
//  Created by Brent Simmons on 8/27/24.
//

import Foundation

final class RSSFeed {

	var urlString: String
	var title: String?
	var link: String?
	var language: String?

	var articles: [RSSArticle]?

	init(urlString: String) {
		self.urlString = urlString
	}
}
