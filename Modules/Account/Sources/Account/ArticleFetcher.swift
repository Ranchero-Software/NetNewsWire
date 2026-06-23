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

@MainActor public protocol ArticleFetcher {
	func fetchArticles() -> Set<Article>
	func fetchArticlesAsync() async -> Set<Article>
	func fetchUnreadArticles() -> Set<Article>
	func fetchUnreadArticlesAsync() async -> Set<Article>
}

extension Feed: ArticleFetcher {

	public func fetchArticles() -> Set<Article> {
		account?.fetchArticles(.feed(self)) ?? Set<Article>()
	}

	public func fetchArticlesAsync() async -> Set<Article> {
		guard let account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}
		return await account.fetchArticlesAsync(.feed(self))
	}

	public func fetchUnreadArticles() -> Set<Article> {
		fetchArticles().unreadArticles()
	}

	public func fetchUnreadArticlesAsync() async -> Set<Article> {
		guard let account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}
		// TODO: fetch only unread articles rather than filtering.
		let articles = await account.fetchArticlesAsync(.feed(self))
		return articles.unreadArticles()
	}
}

extension Folder: ArticleFetcher {

	public func fetchArticles() -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchArticles(.folder(self, false))
	}

	public func fetchArticlesAsync() async -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return await account.fetchArticlesAsync(.folder(self, false))
	}

	public func fetchUnreadArticles() -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchArticles(.folder(self, true))
	}

	public func fetchUnreadArticlesAsync() async -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return await account.fetchArticlesAsync(.folder(self, true))
	}
}
