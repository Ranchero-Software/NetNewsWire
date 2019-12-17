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

protocol SmartFeedDelegate: FeedIdentifiable, DisplayNameProvider, ArticleFetcher, SmallIconProvider {
	var fetchType: FetchType { get }
	func fetchUnreadCount(for: Account, completion: @escaping SingleUnreadCountCompletionBlock)
}

extension SmartFeedDelegate {

	func fetchArticles() throws -> Set<Article> {
		return try AccountManager.shared.fetchArticles(fetchType)
	}

	func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		AccountManager.shared.fetchArticlesAsync(fetchType, completion)
	}

	func fetchUnreadArticles() throws -> Set<Article> {
		return try fetchArticles().unreadArticles()
	}

	func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync{ articleSetResult in
			switch articleSetResult {
			case .success(let articles):
				completion(.success(articles.unreadArticles()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}
