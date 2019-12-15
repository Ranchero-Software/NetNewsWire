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

// This file is the entirety of the public API for ArticlesDatabase.framework.
// Everything else is implementation.

// Main thread only.

public typealias UnreadCountDictionary = [String: Int] // webFeedID: unreadCount
public typealias UnreadCountCompletionBlock = (UnreadCountDictionary) -> Void
public typealias UpdateArticlesCompletionBlock = (Set<Article>?, Set<Article>?) -> Void //newArticles, updatedArticles

public final class ArticlesDatabase {

	/// When ArticlesDatabase is suspended, database calls will crash the app.
	public var isSuspended: Bool {
		return queue.isSuspended
	}

	private let articlesTable: ArticlesTable
	private let queue: DatabaseQueue

	public init(databaseFilePath: String, accountID: String) {
		let queue = DatabaseQueue(databasePath: databaseFilePath)
		self.queue = queue
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue)

		queue.runCreateStatements(ArticlesDatabase.tableCreationStatements)
		queue.runInDatabase { database in
			if !self.articlesTable.containsColumn("searchRowID", in: database) {
				database.executeStatements("ALTER TABLE articles add column searchRowID INTEGER;")
			}
			database.executeStatements("CREATE INDEX if not EXISTS articles_searchRowID on articles(searchRowID);")
			database.executeStatements("DROP TABLE if EXISTS tags;DROP INDEX if EXISTS tags_tagName_index;DROP INDEX if EXISTS articles_feedID_index;DROP INDEX if EXISTS statuses_read_index;DROP TABLE if EXISTS attachments;DROP TABLE if EXISTS attachmentsLookup;")
		}

		queue.vacuumIfNeeded(daysBetweenVacuums: 9)
		DispatchQueue.main.async {
			self.articlesTable.indexUnindexedArticles()
		}
	}

	// MARK: - Fetching Articles

	public func fetchArticles(_ webFeedID: String) -> Set<Article> {
		return articlesTable.fetchArticles(webFeedID)
	}
	
	public func fetchArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticles(webFeedIDs)
	}

	public func fetchArticles(articleIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticles(articleIDs: articleIDs)
	}

	public func fetchUnreadArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchUnreadArticles(webFeedIDs)
	}

	public func fetchTodayArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticlesSince(webFeedIDs, todayCutoffDate())
	}

	public func fetchStarredArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchStarredArticles(webFeedIDs)
	}

	public func fetchArticlesMatching(_ searchString: String, _ webFeedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticlesMatching(searchString, webFeedIDs)
	}

	public func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
	}

	// MARK: - Fetching Articles Async

	public func fetchArticlesAsync(_ webFeedID: String, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesAsync(webFeedID, completion)
	}

	public func fetchArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesAsync(webFeedIDs, completion)
	}

	public func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping  ArticleSetBlock) {
		articlesTable.fetchArticlesAsync(articleIDs: articleIDs, completion)
	}

	public func fetchUnreadArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchUnreadArticlesAsync(webFeedIDs, completion)
	}

	public func fetchTodayArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesSinceAsync(webFeedIDs, todayCutoffDate(), completion)
	}

	public func fetchedStarredArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchStarredArticlesAsync(webFeedIDs, completion)
	}

	public func fetchArticlesMatchingAsync(_ searchString: String, _ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesMatchingAsync(searchString, webFeedIDs, completion)
	}

	public func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
	}

	// MARK: - Unread Counts
	
	public func fetchUnreadCounts(for webFeedIDs: Set<String>, _ completion: @escaping UnreadCountCompletionBlock) {
		articlesTable.fetchUnreadCounts(webFeedIDs, completion)
	}

	public func fetchUnreadCountForToday(for webFeedIDs: Set<String>, completion: @escaping (Int) -> Void) {
		fetchUnreadCount(for: webFeedIDs, since: todayCutoffDate(), completion: completion)
	}

	public func fetchUnreadCount(for webFeedIDs: Set<String>, since: Date, completion: @escaping (Int) -> Void) {
		articlesTable.fetchUnreadCount(webFeedIDs, since, completion)
	}

	public func fetchStarredAndUnreadCount(for webFeedIDs: Set<String>, completion: @escaping (Int) -> Void) {
		articlesTable.fetchStarredAndUnreadCount(webFeedIDs, completion)
	}

	public func fetchAllNonZeroUnreadCounts(_ completion: @escaping UnreadCountCompletionBlock) {
		articlesTable.fetchAllUnreadCounts(completion)
	}

	// MARK: - Saving and Updating Articles

	/// Update articles and save new ones. The key for ewbFeedIDsAndItems is webFeedID.
	public func update(webFeedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping UpdateArticlesCompletionBlock) {
		articlesTable.update(webFeedIDsAndItems, defaultRead, completion)
	}

	public func ensureStatuses(_ articleIDs: Set<String>, _ defaultRead: Bool, _ statusKey: ArticleStatus.Key, _ flag: Bool, completion: VoidCompletionBlock? = nil) {
		articlesTable.ensureStatuses(articleIDs, defaultRead, statusKey, flag, completion: completion)
	}
	
	// MARK: - Status

	/// Fetch the articleIDs of unread articles in feeds specified by webFeedIDs.
	public func fetchUnreadArticleIDsAsync(webFeedIDs: Set<String>, completion: @escaping (Set<String>) -> Void) {
		articlesTable.fetchUnreadArticleIDsAsync(webFeedIDs, completion)
	}
	
	/// Fetch the articleIDs of starred articles in feeds specified by webFeedIDs.
	public func fetchStarredArticleIDsAsync(webFeedIDs: Set<String>, completion: @escaping (Set<String>) -> Void) {
		articlesTable.fetchStarredArticleIDsAsync(webFeedIDs, completion)
	}

	public func fetchArticleIDsForStatusesWithoutArticles() -> Set<String> {
		return articlesTable.fetchArticleIDsForStatusesWithoutArticles()
	}
	
	public func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<ArticleStatus>? {
		return articlesTable.mark(articles, statusKey, flag)
	}

	public func fetchStatuses(articleIDs: Set<String>, createIfNeeded: Bool, completion: @escaping (Set<ArticleStatus>?) -> Void) {
		articlesTable.fetchStatuses(articleIDs, createIfNeeded, completion)
	}

	// MARK: - Suspend and Resume (for iOS)

	/// Close the database and stop running database calls.
	/// Any pending calls will complete first.
	public func suspend() {
		queue.suspend()
	}

	/// Open the database and allow for running database calls again.
	public func resume() {
		queue.resume()
	}

	// MARK: - Caches

	/// Call to free up some memory. Should be done when the app is backgrounded, for instance.
	/// This does not empty *all* caches — just the ones that are empty-able.
	public func emptyCaches() {
		articlesTable.emptyCaches()
	}

	// MARK: - Cleanup

	// These are to be used only at startup. These are to prevent the database from growing forever.

	/// Calls the various clean-up functions.
	public func cleanupDatabaseAtStartup(subscribedToWebFeedIDs: Set<String>) {
		articlesTable.deleteArticlesNotInSubscribedToFeedIDs(subscribedToWebFeedIDs)
	}
}

// MARK: - Private

private extension ArticlesDatabase {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE, searchRowID INTEGER);

	CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

	CREATE TABLE if not EXISTS authors (authorID TEXT NOT NULL PRIMARY KEY, name TEXT, url TEXT, avatarURL TEXT, emailAddress TEXT);
	CREATE TABLE if not EXISTS authorsLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));

	CREATE INDEX if not EXISTS articles_feedID_datePublished_articleID on articles (feedID, datePublished, articleID);

	CREATE INDEX if not EXISTS statuses_starred_index on statuses (starred);

	CREATE VIRTUAL TABLE if not EXISTS search using fts4(title, body);

	CREATE TRIGGER if not EXISTS articles_after_delete_trigger_delete_search_text after delete on articles begin delete from search where rowid = OLD.searchRowID; end;
	"""

	func todayCutoffDate() -> Date {
		// 24 hours previous. This is used by the Today smart feed, which should not actually empty out at midnight.
		return Date(timeIntervalSinceNow: -(60 * 60 * 24)) // This does not need to be more precise.
	}
}
