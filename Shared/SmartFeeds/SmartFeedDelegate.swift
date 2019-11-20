//
//  SmartFeedDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles
import RSCore

protocol SmartFeedDelegate: FeedIdentifiable, DisplayNameProvider, ArticleFetcher, SmallIconProvider {
	var fetchType: FetchType { get }
	func fetchUnreadCount(for: Account, callback: @escaping (Int) -> Void)
}

extension SmartFeedDelegate {

	func fetchArticles() -> Set<Article> {
		return AccountManager.shared.fetchArticles(fetchType)
	}

	func fetchArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		AccountManager.shared.fetchArticlesAsync(fetchType, callback)
	}

	func fetchUnreadArticles() -> Set<Article> {
		return fetchArticles().unreadArticles()
	}

	func fetchUnreadArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		fetchArticlesAsync{ callback($0.unreadArticles()) }
	}
}
