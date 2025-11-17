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
	@MainActor func fetchArticlesAsync() async throws -> Set<Article>
	@MainActor func fetchUnreadArticles() throws -> Set<Article>
	@MainActor func fetchUnreadArticlesAsync() async throws -> Set<Article>
}

@MainActor extension Feed: ArticleFetcher {

	public func fetchArticles() throws -> Set<Article> {
		return try account?.fetchArticles(.feed(self)) ?? Set<Article>()
	}

	public func fetchArticlesAsync() async throws -> Set<Article> {
		guard let account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}
		return try await account.fetchArticlesAsync(.feed(self))
	}

	public func fetchUnreadArticles() throws -> Set<Article> {
		return try fetchArticles().unreadArticles()
	}

	public func fetchUnreadArticlesAsync() async throws -> Set<Article> {
		guard let account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}
		// TODO: fetch only unread articles rather than filtering.
		let articles = try await account.fetchArticlesAsync(.feed(self))
		return articles.unreadArticles()
	}
}

@MainActor extension Folder: ArticleFetcher {

	public func fetchArticles() throws -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return try account.fetchArticles(.folder(self, false))
	}

	public func fetchArticlesAsync() async throws -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return try await account.fetchArticlesAsync(.folder(self, false))
	}

	public func fetchUnreadArticles() throws -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return try account.fetchArticles(.folder(self, true))
	}

	public func fetchUnreadArticlesAsync() async throws -> Set<Article> {
		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return try await account.fetchArticlesAsync(.folder(self, true))
	}
}
