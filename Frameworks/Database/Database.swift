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

	public init(databaseFilePath: String, accountID: String) {

		self.accountID = accountID
		
		let queue = RSDatabaseQueue(filepath: databaseFilePath, excludeFromBackup: false)
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue)

		let createStatementsPath = Bundle(for: type(of: self)).path(forResource: "CreateStatements", ofType: "sql")!
		let createStatements = try! NSString(contentsOfFile: createStatementsPath, encoding: String.Encoding.utf8.rawValue)
		queue.createTables(usingStatements: createStatements as String)
		queue.update { (database) in
			database.executeStatements("DROP TABLE if EXISTS tags;DROP INDEX if EXISTS tags_tagName_index;")
		}
		queue.vacuumIfNeeded()
	}

	// MARK: - Fetching Articles

	public func fetchArticles(for feed: Feed) -> Set<Article> {

		return articlesTable.fetchArticles(feed)
	}

	public func fetchArticlesAsync(for feed: Feed, _ resultBlock: @escaping ArticleResultBlock) {

		articlesTable.fetchArticlesAsync(feed, withLimits: true, resultBlock)
	}

	public func fetchUnreadArticles(for feeds: Set<Feed>) -> Set<Article> {
		
		return articlesTable.fetchUnreadArticles(for: feeds)
	}

	public func fetchTodayArticles(for feeds: Set<Feed>) -> Set<Article> {
		
		return articlesTable.fetchTodayArticles(for: feeds)
	}

	public func fetchStarredArticles(for feeds: Set<Feed>) -> Set<Article> {

		return articlesTable.fetchStarredArticles(for: feeds)
	}

	// MARK: - Unread Counts
	
	public func fetchUnreadCounts(for feeds: Set<Feed>, _ completion: @escaping UnreadCountCompletionBlock) {

		articlesTable.fetchUnreadCounts(feeds, completion)
	}

	public func fetchUnreadCount(for feeds: Set<Feed>, since: Date, callback: @escaping (Int) -> Void) {

		articlesTable.fetchUnreadCount(feeds, since, callback)
	}

	public func fetchStarredAndUnreadCount(for feeds: Set<Feed>, callback: @escaping (Int) -> Void) {

		articlesTable.fetchStarredAndUnreadCount(feeds, callback)
	}

	public func fetchAllNonZeroUnreadCounts(_ completion: @escaping UnreadCountCompletionBlock) {

		articlesTable.fetchAllUnreadCounts(completion)
	}

	// MARK: - Saving and Updating Articles

	public func update(feed: Feed, parsedFeed: ParsedFeed, completion: @escaping UpdateArticlesWithFeedCompletionBlock) {

		return articlesTable.update(feed, parsedFeed, completion)
	}
	
	// MARK: - Status
	
	public func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<ArticleStatus>? {

		return articlesTable.mark(articles, statusKey, flag)
	}

	public func markEverywhereAsRead() {

		articlesTable.markEverywhereAsRead()
	}
}

