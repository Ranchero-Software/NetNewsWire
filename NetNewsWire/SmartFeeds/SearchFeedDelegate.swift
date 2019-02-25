//
//  SearchFeedDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles

struct SearchFeedDelegate: SmartFeedDelegate {

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
	let searchString: String

	init(searchString: String) {
		self.searchString = searchString
	}

	func fetchUnreadCount(for: Account, callback: @escaping (Int) -> Void) {
		// TODO: after 5.0
	}
}

// MARK: - ArticleFetcher

extension SearchFeedDelegate: ArticleFetcher {

	func fetchArticles() -> Set<Article> {
		var articles = Set<Article>()
		for account in AccountManager.shared.accounts {
			articles.formUnion(account.fetchArticlesMatching(searchString))
		}
		return articles
	}

	func fetchUnreadArticles() -> Set<Article> {
		return fetchArticles().unreadArticles()
	}
}
