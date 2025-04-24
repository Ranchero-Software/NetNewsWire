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

	func fetchArticles() throws -> Set<Article>
	func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock)
	func fetchUnreadArticles() throws -> Set<Article>
	func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock)
}

extension WebFeed: ArticleFetcher {
	
	public func fetchArticles() throws -> Set<Article> {
		return try account?.fetchArticles(.webFeed(self)) ?? Set<Article>()
	}

	public func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			completion(.success(Set<Article>()))
			return
		}
		account.fetchArticlesAsync(.webFeed(self), completion)
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
		account.fetchArticlesAsync(.webFeed(self)) { articleSetResult in
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
