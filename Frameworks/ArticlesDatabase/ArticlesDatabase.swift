//
//  ArticlesDatabase.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSParser
import Articles

// This file and UnreadCountDictionary are the entirety of the public API for Database.framework.
// Everything else is implementation.

public typealias ArticleResultBlock = (Set<Article>) -> Void
public typealias UnreadCountCompletionBlock = (UnreadCountDictionary) -> Void
public typealias UpdateArticlesWithFeedCompletionBlock = (Set<Article>?, Set<Article>?) -> Void //newArticles, updatedArticles

public final class ArticlesDatabase {

	private let accountID: String
	private let articlesTable: ArticlesTable

	public init(databaseFilePath: String, accountID: String) {
		self.accountID = accountID
		
		let queue = RSDatabaseQueue(filepath: databaseFilePath, excludeFromBackup: false)
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue)

		queue.createTables(usingStatements: ArticlesDatabase.tableCreationStatements)
		queue.update { (database) in
			if !self.articlesTable.containsColumn("searchRowID", in: database) {
				database.executeStatements("ALTER TABLE articles add column searchRowID INTEGER;")
			}
			database.executeStatements("CREATE INDEX if not EXISTS articles_searchRowID on articles(searchRowID);")
			database.executeStatements("DROP TABLE if EXISTS tags;DROP INDEX if EXISTS tags_tagName_index;DROP INDEX if EXISTS articles_feedID_index;DROP INDEX if EXISTS statuses_read_index;")
		}
		queue.vacuumIfNeeded()
		DispatchQueue.main.async {
			self.articlesTable.indexUnindexedArticles()
		}
	}

	// MARK: - Fetching Articles

	public func fetchArticles(for feedID: String) -> Set<Article> {
		return articlesTable.fetchArticles(feedID)
	}

	public func fetchArticlesAsync(for feedID: String, _ resultBlock: @escaping ArticleResultBlock) {
		articlesTable.fetchArticlesAsync(feedID, withLimits: true, resultBlock)
	}

	public func fetchUnreadArticles(for feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchUnreadArticles(for: feedIDs)
	}

	public func fetchTodayArticles(for feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchTodayArticles(for: feedIDs)
	}

	public func fetchStarredArticles(for feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchStarredArticles(for: feedIDs)
	}

	public func fetchArticlesMatching(_ searchString: String, for feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticlesMatching(searchString, for: feedIDs)
	}

	// MARK: - Unread Counts
	
	public func fetchUnreadCounts(for feedIDs: Set<String>, _ completion: @escaping UnreadCountCompletionBlock) {
		articlesTable.fetchUnreadCounts(feedIDs, completion)
	}

	public func fetchUnreadCount(for feedIDs: Set<String>, since: Date, callback: @escaping (Int) -> Void) {
		articlesTable.fetchUnreadCount(feedIDs, since, callback)
	}

	public func fetchStarredAndUnreadCount(for feedIDs: Set<String>, callback: @escaping (Int) -> Void) {
		articlesTable.fetchStarredAndUnreadCount(feedIDs, callback)
	}

	public func fetchAllNonZeroUnreadCounts(_ completion: @escaping UnreadCountCompletionBlock) {
		articlesTable.fetchAllUnreadCounts(completion)
	}

	// MARK: - Saving and Updating Articles

	public func update(feedID: String, parsedFeed: ParsedFeed, completion: @escaping UpdateArticlesWithFeedCompletionBlock) {
		return articlesTable.update(feedID, parsedFeed, completion)
	}
	
	// MARK: - Status
	
	public func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<ArticleStatus>? {
		return articlesTable.mark(articles, statusKey, flag)
	}
}

// MARK: - Private

private extension ArticlesDatabase {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE, searchRowID INTEGER);

	CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

	CREATE TABLE if not EXISTS authors (authorID TEXT NOT NULL PRIMARY KEY, name TEXT, url TEXT, avatarURL TEXT, emailAddress TEXT);
	CREATE TABLE if not EXISTS authorsLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));

	CREATE TABLE if not EXISTS attachments(attachmentID TEXT NOT NULL PRIMARY KEY, url TEXT NOT NULL, mimeType TEXT, title TEXT, sizeInBytes INTEGER, durationInSeconds INTEGER);
	CREATE TABLE if not EXISTS attachmentsLookup(attachmentID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(attachmentID, articleID));

	CREATE INDEX if not EXISTS articles_feedID_datePublished_articleID on articles (feedID, datePublished, articleID);

	CREATE INDEX if not EXISTS statuses_starred_index on statuses (starred);

	CREATE VIRTUAL TABLE if not EXISTS search using fts4(title, body);

	CREATE TRIGGER if not EXISTS articles_after_delete_trigger_delete_search_text after delete on articles begin delete from search where rowid = OLD.searchRowID; end;
	"""
}
