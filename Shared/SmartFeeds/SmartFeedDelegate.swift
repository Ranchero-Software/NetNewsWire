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
import ArticlesDatabase
import RSCore

@MainActor protocol SmartFeedDelegate: SidebarItemIdentifiable, DisplayNameProvider, ArticleFetcher, SmallIconProvider {
	var fetchType: FetchType { get }
	func fetchUnreadCount(account: Account) async -> Int
}

@MainActor extension SmartFeedDelegate {

	func fetchArticles() -> Set<Article> {
		AccountManager.shared.fetchArticles(fetchType)
	}

	func fetchArticlesAsync() async -> Set<Article> {
		await AccountManager.shared.fetchArticlesAsync(fetchType)
	}

	func fetchUnreadArticles() -> Set<Article> {
		fetchArticles().unreadArticles()
	}

	func fetchUnreadArticlesAsync() async -> Set<Article> {
		let articles = await fetchArticlesAsync()
		return articles.unreadArticles()
	}
}
