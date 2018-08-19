//
//  ArticleFetcher.swift
//  Account
//
//  Created by Brent Simmons on 2/4/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles

public protocol ArticleFetcher {

	func fetchArticles() -> Set<Article>
	func fetchUnreadArticles() -> Set<Article>
}

extension Feed: ArticleFetcher {

	public func fetchArticles() -> Set<Article> {

		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchArticles(for: self)
	}

	public func fetchUnreadArticles() -> Set<Article> {

		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchUnreadArticles(for: self)
	}
}

extension Folder: ArticleFetcher {

	public func fetchArticles() -> Set<Article> {

		return fetchUnreadArticles()
	}

	public func fetchUnreadArticles() -> Set<Article> {

		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}

		return account.fetchArticles(folder: self)
	}
}
