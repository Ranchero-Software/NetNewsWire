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
	func fetchUnreadCount(for: Account, completion: @escaping (Int) -> Void)
}

extension SmartFeedDelegate {

	func fetchArticles() -> Set<Article> {
		return AccountManager.shared.fetchArticles(fetchType)
	}

	func fetchArticlesAsync(_ completion: @escaping ArticleSetBlock) {
		AccountManager.shared.fetchArticlesAsync(fetchType, completion)
	}

	func fetchUnreadArticles() -> Set<Article> {
		return fetchArticles().unreadArticles()
	}

	func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync{ completion($0.unreadArticles()) }
	}
}
