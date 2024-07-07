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

	@MainActor func fetchArticles() async throws -> Set<Article>
	@MainActor func fetchUnreadArticles() async throws -> Set<Article>
}

extension Feed: ArticleFetcher {
	
	public func fetchArticles() async throws -> Set<Article> {

		guard let account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}

		return try await account.articles(feed: self)
	}

	public func fetchUnreadArticles() async throws -> Set<Article> {

		guard let account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}

		return try await account.unreadArticles(feed: self)
	}
}

extension Folder: ArticleFetcher {

	public func fetchArticles() async throws -> Set<Articles.Article> {

		try await articles(unreadOnly: false)
	}
	
	public func fetchUnreadArticles() async throws -> Set<Article> {

		try await articles(unreadOnly: true)
	}
}

private extension Folder {

	func articles(unreadOnly: Bool = false) async throws -> Set<Article> {

		guard let account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}

		return try await account.articles(for: .folder(self, unreadOnly))
	}
}
