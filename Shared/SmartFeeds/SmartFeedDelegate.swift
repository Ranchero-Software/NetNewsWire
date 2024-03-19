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
import Database

protocol SmartFeedDelegate: SidebarItemIdentifiable, DisplayNameProvider, ArticleFetcher, SmallIconProvider {

	var fetchType: FetchType { get }

	func fetchUnreadCount(for: Account, completion: @escaping SingleUnreadCountCompletionBlock)
}

extension SmartFeedDelegate {

	@MainActor func fetchArticles() async throws -> Set<Article> {

		try await AccountManager.shared.fetchArticles(fetchType: fetchType)
	}

	@MainActor func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		AccountManager.shared.fetchArticlesAsync(fetchType, completion)
	}

	@MainActor func fetchUnreadArticles() async throws -> Set<Article> {

		try await AccountManager.shared.fetchArticles(fetchType: fetchType)
	}

	@MainActor func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		
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
