//
//  ArticlesDatabase.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSDatabase
import RSParser
import Articles

// This file is the entirety of the public API for ArticlesDatabase.framework.
// Everything else is implementation.

// Main thread only.

public typealias UnreadCountDictionary = [String: Int] // feedID: unreadCount
public typealias UnreadCountCompletionBlock = (UnreadCountDictionary) -> Void

public struct ArticleChanges {
	public let newArticles: Set<Article>?
	public let updatedArticles: Set<Article>?
	public let deletedArticles: Set<Article>?
}
public typealias UpdateArticlesCompletionBlock = (ArticleChanges) -> Void


public final class ArticlesDatabase {

	public enum RetentionStyle {
		case feedBased // Local and iCloud: article retention is defined by contents of feed
		case syncSystem // Feedbin, Feedly, etc.: article retention is defined by external system
	}

	/// When ArticlesDatabase is suspended, database calls will crash the app.
	public var isSuspended: Bool {
		return queue.isSuspended
	}

	private let articlesTable: ArticlesTable
	private let queue: DatabaseQueue
	private let retentionStyle: RetentionStyle

	public init(databaseFilePath: String, accountID: String, retentionStyle: RetentionStyle) {
		let queue = DatabaseQueue(databasePath: databaseFilePath)
		self.queue = queue
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue, retentionStyle: retentionStyle)
		self.retentionStyle = retentionStyle

		queue.runCreateStatements(ArticlesDatabase.tableCreationStatements)
		queue.runInDatabase { database in
			if !self.articlesTable.containsColumn("searchRowID", in: database) {
				database.executeStatements("ALTER TABLE articles add column searchRowID INTEGER;")
			}
			database.executeStatements("CREATE INDEX if not EXISTS articles_searchRowID on articles(searchRowID);")
			database.executeStatements("DROP TABLE if EXISTS tags;DROP INDEX if EXISTS tags_tagName_index;DROP INDEX if EXISTS articles_feedID_index;DROP INDEX if EXISTS statuses_read_index;DROP TABLE if EXISTS attachments;DROP TABLE if EXISTS attachmentsLookup;")
		}

		DispatchQueue.main.async {
			self.articlesTable.indexUnindexedArticles()
		}
	}

	// MARK: - Fetching Articles

	public func fetchArticles(_ feedID: String) -> Set<Article> {
		return articlesTable.fetchArticles(feedID)
	}
	
	public func fetchArticles(articleIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticles(articleIDs: articleIDs)
	}

	public func fetchUnreadArticles(_ feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchUnreadArticles(feedIDs)
	}

	public func fetchTodayArticles(_ feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticlesSince(feedIDs, todayCutoffDate())
	}

	public func fetchStarredArticles(_ feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchStarredArticles(feedIDs)
	}

	public func fetchArticlesMatching(_ searchString: String, _ feedIDs: Set<String>) -> Set<Article> {
		return articlesTable.fetchArticlesMatching(searchString, feedIDs)
	}

	// MARK: - Fetching Articles Async

	public func fetchArticlesAsync(_ feedID: String, _ callback: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesAsync(feedID, callback)
	}

	public func fetchArticlesAsync(articleIDs: Set<String>, _ callback: @escaping  ArticleSetBlock) {
		articlesTable.fetchArticlesAsync(articleIDs: articleIDs, callback)
	}

	public func fetchUnreadArticlesAsync(_ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		articlesTable.fetchUnreadArticlesAsync(feedIDs, callback)
	}

	public func fetchTodayArticlesAsync(_ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesSinceAsync(feedIDs, todayCutoffDate(), callback)
	}

	public func fetchedStarredArticlesAsync(_ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		articlesTable.fetchStarredArticlesAsync(feedIDs, callback)
	}

	public func fetchArticlesMatchingAsync(_ searchString: String, _ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		articlesTable.fetchArticlesMatchingAsync(searchString, feedIDs, callback)
	}

	// MARK: - Unread Counts
	
	public func fetchUnreadCounts(for feedIDs: Set<String>, _ callback: @escaping UnreadCountCompletionBlock) {
		articlesTable.fetchUnreadCounts(feedIDs, callback)
	}

	public func fetchUnreadCountForToday(for feedIDs: Set<String>, callback: @escaping (Int) -> Void) {
		fetchUnreadCount(for: feedIDs, since: todayCutoffDate(), callback: callback)
	}

	public func fetchUnreadCount(for feedIDs: Set<String>, since: Date, callback: @escaping (Int) -> Void) {
		articlesTable.fetchUnreadCount(feedIDs, since, callback)
	}

	public func fetchStarredAndUnreadCount(for feedIDs: Set<String>, callback: @escaping (Int) -> Void) {
		articlesTable.fetchStarredAndUnreadCount(feedIDs, callback)
	}

	public func fetchAllNonZeroUnreadCounts(_ callback: @escaping UnreadCountCompletionBlock) {
		articlesTable.fetchAllUnreadCounts(callback)
	}

	// MARK: - Saving and Updating Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	public func update(with parsedItems: Set<ParsedItem>, feedID: String, completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .feedBased)
		articlesTable.update(parsedItems, feedID, completion)
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	public func update(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .syncSystem)
		articlesTable.update(feedIDsAndItems, defaultRead, completion)
	}

	public func ensureStatuses(_ articleIDs: Set<String>, _ defaultRead: Bool, _ statusKey: ArticleStatus.Key, _ flag: Bool) {
		articlesTable.ensureStatuses(articleIDs, defaultRead, statusKey, flag)
	}
	
	// MARK: - Status
	
	public func fetchUnreadArticleIDs() -> Set<String> {
		return articlesTable.fetchUnreadArticleIDs()
	}
	
	public func fetchStarredArticleIDs() -> Set<String> {
		return articlesTable.fetchStarredArticleIDs()
	}
	
	public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate() -> Set<String> {
		return articlesTable.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate()
	}
	
	public func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<ArticleStatus>? {
		return articlesTable.mark(articles, statusKey, flag)
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

	/// Calls the various clean-up functions. To be used only at startup.
	///
	/// This prevents the database from growing forever. If we didn’t do this:
	/// 1) The database would grow to an inordinate size, and
	/// 2) the app would become very slow.
	public func cleanupDatabaseAtStartup(subscribedToWebFeedIDs: Set<String>) {
		if retentionStyle == .syncSystem {
			articlesTable.deleteOldArticles()
		}
		articlesTable.deleteArticlesNotInSubscribedToFeedIDs(subscribedToWebFeedIDs)
		articlesTable.deleteOldStatuses()
	}

	/// Do database cleanups made necessary by the retention policy change in April 2020.
	///
	/// The retention policy for feed-based systems changed in April 2020:
	/// we keep articles only for as long as they’re in the feed.
	/// This change could result in a bunch of older articles suddenly
	/// appearing as unread articles.
	///
	/// These are articles that were in the database,
	/// but weren’t appearing in the UI because they were beyond the 90-day window.
	/// (The previous retention policy used a 90-day window.)
	///
	/// This function marks everything as read that’s beyond that 90-day window.
	/// It’s intended to be called only once on an account.
	public func performApril2020RetentionPolicyChange() {
		precondition(retentionStyle == .feedBased)
		articlesTable.markOlderStatusesAsRead()
	}
}

// MARK: - Private

private extension ArticlesDatabase {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE, searchRowID INTEGER);

	CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

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
