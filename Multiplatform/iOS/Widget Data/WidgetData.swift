//
//  WidgetData.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 10/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

struct WidgetData: Codable {

	let currentUnreadCount: Int
	let currentTodayCount: Int
	let latestArticles: [LatestArticle]
	let lastUpdateTime: Date

}

struct LatestArticle: Codable {

	let feedTitle: String
	let articleTitle: String?
	let articleSummary: String?
	let feedIcon: Data? // Base64 encoded image data
	let pubDate: String

}
