//
//  TodayFeedDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account

struct TodayFeedDelegate: SmartFeedDelegate {

	let nameForDisplay = NSLocalizedString("Today", comment: "Today pseudo-feed title")

	func fetchUnreadCount(for account: Account, callback: @escaping (Int) -> Void) {

		account.fetchUnreadCountForToday(callback)
	}

	// MARK: ArticleFetcher

	func fetchArticles() -> Set<Article> {

		var articles = Set<Article>()
		for account in AccountManager.shared.accounts {
			articles.formUnion(account.fetchTodayArticles())
		}
		return articles
	}

	func fetchUnreadArticles() -> Set<Article> {

		return fetchArticles().unreadArticles()
	}
}

