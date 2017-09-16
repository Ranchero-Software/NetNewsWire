//
//  Database.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSParser
import Data

// This file and UnreadCountDictionary are the entirety of the public API for Database.framework.
// Everything else is implementation.

public typealias ArticleResultBlock = (Set<Article>) -> Void
public typealias UnreadCountCompletionBlock = (UnreadCountDictionary) -> Void
public typealias UpdateArticlesWithFeedCompletionBlock = (Set<Article>?, Set<Article>?) -> Void //newArticles, updatedArticles

public final class Database {

	private let accountID: String
	private let articlesTable: ArticlesTable

	public init(databaseFile: String, accountID: String) {

		self.accountID = accountID
		
		let queue = RSDatabaseQueue(filepath: databaseFile, excludeFromBackup: false)
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue)

		let createStatementsPath = Bundle(for: type(of: self)).path(forResource: "CreateStatements", ofType: "sql")!
		let createStatements = try! NSString(contentsOfFile: createStatementsPath, encoding: String.Encoding.utf8.rawValue)
		queue.createTables(usingStatements: createStatements as String)
		queue.vacuumIfNeeded()
	}

	// MARK: - Fetching Articles

	public func fetchArticles(for feed: Feed) -> Set<Article> {

		return articlesTable.fetchArticles(feed)
	}

	public func fetchArticlesAsync(for feed: Feed, _ resultBlock: @escaping ArticleResultBlock) {

		articlesTable.fetchArticlesAsync(feed, withLimits: true, resultBlock)
	}

	public func fetchUnreadArticles(for folder: Folder) -> Set<Article> {
		
		return articlesTable.fetchUnreadArticles(for: folder.flattenedFeeds())
	}

	// MARK: - Unread Counts
	
	public func fetchUnreadCounts(for feeds: Set<Feed>, _ completion: @escaping UnreadCountCompletionBlock) {
		
		articlesTable.fetchUnreadCounts(feeds, completion)
	}

	// MARK: - Saving and Updating Articles

	public func update(feed: Feed, parsedFeed: ParsedFeed, completion: @escaping UpdateArticlesWithFeedCompletionBlock) {

		return articlesTable.update(feed, parsedFeed, completion)
	}
	
	// MARK: - Status
	
	public func mark(_ statuses: Set<ArticleStatus>, statusKey: String, flag: Bool) {

		articlesTable.mark(statuses, statusKey, flag)
	}
}

