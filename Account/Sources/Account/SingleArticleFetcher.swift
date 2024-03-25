//
//  SingleArticleFetcher.swift
//  Account
//
//  Created by Maurice Parker on 11/29/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import ArticlesDatabase

public struct SingleArticleFetcher {

	private let account: Account
	private let articleID: String

	public init(account: Account, articleID: String) {
		self.account = account
		self.articleID = articleID
	}
}

extension SingleArticleFetcher: ArticleFetcher {

	public func fetchArticles() async throws -> Set<Article> {

		try await account.articles(articleIDs: Set([articleID]))
	}

	// Doesn’t actually fetch unread articles. Fetches whatever articleID it is asked to fetch.

	public func fetchUnreadArticles() async throws -> Set<Article> {

		try await fetchArticles()
	}
}
