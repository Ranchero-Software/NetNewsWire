//
//  ArticleFetcher.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/4/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import ArticlesDatabase

public protocol ArticleFetcher {

	@MainActor func fetchArticles() throws -> Set<Article>
	@MainActor func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock)
	@MainActor func fetchUnreadArticles() throws -> Set<Article>
	@MainActor func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock)
}

@MainActor extension Feed: ArticleFetcher {

	public func fetchArticles() throws -> Set<Article> {
		return try account?.fetchArticles(.feed(self)) ?? Set<Article>()
	}

	public func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			completion(.success(Set<Article>()))
			return
		}
		account.fetchArticlesAsync(.feed(self), completion)
	}

	public func fetchUnreadArticles() throws -> Set<Article> {
		return try fetchArticles().unreadArticles()
	}

	public func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			completion(.success(Set<Article>()))
			return
		}
		account.fetchArticlesAsync(.feed(self)) { articleSetResult in
			switch articleSetResult {
			case .success(let articles):
				completion(.success(articles.unreadArticles()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension Folder: ArticleFetcher {

	public func fetchArticles() throws -> Set<Article> {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return try account.fetchArticles(.folder(self, false))
	}

	public func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			completion(.success(Set<Article>()))
			return
		}
		account.fetchArticlesAsync(.folder(self, false), completion)
	}

	public func fetchUnreadArticles() throws -> Set<Article> {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return try account.fetchArticles(.folder(self, true))
	}

	public func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			completion(.success(Set<Article>()))
			return
		}
		account.fetchArticlesAsync(.folder(self, true), completion)
	}
}
