//
//  ArticleFetcher.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/4/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles

public protocol ArticleFetcher {

	func fetchArticles() -> Set<Article>
	func fetchArticlesAsync(_ completion: @escaping ArticleSetBlock)
	func fetchUnreadArticles() -> Set<Article>
	func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetBlock)
}

extension WebFeed: ArticleFetcher {
	
	public func fetchArticles() -> Set<Article> {
		return account?.fetchArticles(.webFeed(self)) ?? Set<Article>()
	}

	public func fetchArticlesAsync(_ completion: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			completion(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.webFeed(self), completion)
	}

	public func fetchUnreadArticles() -> Set<Article> {
		return fetchArticles().unreadArticles()
	}

	public func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			completion(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.webFeed(self)) { completion($0.unreadArticles()) }
	}
}

extension Folder: ArticleFetcher {
	
	public func fetchArticles() -> Set<Article> {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchArticles(.folder(self, false))
	}

	public func fetchArticlesAsync(_ completion: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			completion(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.folder(self, false), completion)
	}

	public func fetchUnreadArticles() -> Set<Article> {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchArticles(.folder(self, true))
	}

	public func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			completion(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.folder(self, true), completion)
	}
}
