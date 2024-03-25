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
import Database
import Core

protocol SmartFeedDelegate: SidebarItemIdentifiable, DisplayNameProvider, ArticleFetcher, SmallIconProvider {

	@MainActor var fetchType: FetchType { get }

	@MainActor func unreadCount(account: Account) async -> Int
}

extension SmartFeedDelegate {

	@MainActor func fetchArticles() async throws -> Set<Article> {

		try await AccountManager.shared.fetchArticles(fetchType: fetchType)
	}

	@MainActor func fetchUnreadArticles() async throws -> Set<Article> {

		try await AccountManager.shared.fetchArticles(fetchType: fetchType)
	}
}
