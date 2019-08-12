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
	func fetchArticlesAsync(_ callback: @escaping ArticleSetBlock)
	func fetchUnreadArticles() -> Set<Article>
	func fetchUnreadArticlesAsync(_ callback: @escaping ArticleSetBlock)
}

extension Feed: ArticleFetcher {

	public func fetchArticles() -> Set<Article> {
		return account?.fetchArticles(.feed(self)) ?? Set<Article>()
	}

	public func fetchArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			callback(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.feed(self), callback)
	}

	public func fetchUnreadArticles() -> Set<Article> {
		return fetchArticles().unreadArticles()
	}

	public func fetchUnreadArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected feed.account, but got nil.")
			callback(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.feed(self)) { callback($0.unreadArticles()) }
	}
}

extension Folder: ArticleFetcher {

	public func fetchArticles() -> Set<Article> {
		return fetchUnreadArticles()
	}

	public func fetchArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		fetchUnreadArticlesAsync(callback)
	}

	public func fetchUnreadArticles() -> Set<Article> {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			return Set<Article>()
		}
		return account.fetchArticles(.unreadForFolder(self))
	}

	public func fetchUnreadArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		guard let account = account else {
			assertionFailure("Expected folder.account, but got nil.")
			callback(Set<Article>())
			return
		}
		account.fetchArticlesAsync(.unreadForFolder(self), callback)
	}
}
