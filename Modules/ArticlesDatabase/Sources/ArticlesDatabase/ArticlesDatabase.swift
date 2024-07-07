//
//  ArticlesDatabase.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Database
import FMDB
import Articles
import Parser

public typealias UnreadCountDictionary = [String: Int] // feedID: unreadCount

public struct ArticleChanges: Sendable {
	public let newArticles: Set<Article>?
	public let updatedArticles: Set<Article>?
	public let deletedArticles: Set<Article>?

	public init() {
		self.newArticles = Set<Article>()
		self.updatedArticles = Set<Article>()
		self.deletedArticles = Set<Article>()
	}

	public init(newArticles: Set<Article>?, updatedArticles: Set<Article>?, deletedArticles: Set<Article>?) {
		self.newArticles = newArticles
		self.updatedArticles = updatedArticles
		self.deletedArticles = deletedArticles
	}
}

/// Fetch articles and unread counts. Save articles. Mark as read/unread and starred/unstarred.
public actor ArticlesDatabase {

	public enum RetentionStyle: Sendable {
		/// Local and iCloud: article retention is defined by contents of feed
		case feedBased
		/// Feedbin, Feedly, etc.: article retention is defined by external system
		case syncSystem
	}

	private var database: FMDatabase?
	private var databasePath: String
	private let retentionStyle: RetentionStyle
	private let articlesTable: ArticlesTable

	public init(databasePath: String, accountID: String, retentionStyle: RetentionStyle) {

		let database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		database.runCreateStatements(ArticlesDatabase.creationStatements)

		self.database = database
		self.databasePath = databasePath
		self.retentionStyle = retentionStyle
		self.articlesTable = ArticlesTable(accountID: accountID, retentionStyle: retentionStyle)

		// Migrate from older schemas
		database.beginTransaction()
		if !database.columnExists("searchRowID", inTableWithName: DatabaseTableName.articles) {
			database.executeStatements("ALTER TABLE articles add column searchRowID INTEGER;")
		}
		database.executeStatements("CREATE INDEX if not EXISTS articles_searchRowID on articles(searchRowID);")
		database.executeStatements("DROP TABLE if EXISTS tags;DROP INDEX if EXISTS tags_tagName_index;DROP INDEX if EXISTS articles_feedID_index;DROP INDEX if EXISTS statuses_read_index;DROP TABLE if EXISTS attachments;DROP TABLE if EXISTS attachmentsLookup;")
		database.commit()

		Task {
			await self.indexUnindexedArticles()
		}
	}

	// MARK: - Articles

	public func articles(feedID: String) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.articles(feedID: feedID, database: database)
	}

	public func articles(feedIDs: Set<String>) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.articles(feedIDs: feedIDs, database: database)
	}

	public func articles(articleIDs: Set<String>) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.articles(articleIDs: articleIDs, database: database)
	}

	public func unreadArticles(feedIDs: Set<String>, limit: Int? = nil) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.unreadArticles(feedIDs: feedIDs, limit: limit, database: database)
	}

	public func todayArticles(feedIDs: Set<String>, limit: Int? = nil) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.todayArticles(feedIDs: feedIDs, cutoffDate: todayCutoffDate(), limit: limit, database: database)
	}

	public func starredArticles(feedIDs: Set<String>, limit: Int? = nil) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.starredArticles(feedIDs: feedIDs, limit: limit, database: database)
	}

	public func articlesMatching(searchString: String, feedIDs: Set<String>) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.articlesMatching(searchString: searchString, feedIDs: feedIDs, database: database)
	}

	public func articlesMatching(searchString: String, articleIDs: Set<String>) throws -> Set<Article> {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.articlesMatching(searchString: searchString, articleIDs: articleIDs, database: database)
	}

	// MARK: - Unread Counts

	/// Fetch all non-zero unread counts.
	public func allUnreadCounts() throws -> UnreadCountDictionary {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.allUnreadCounts(database: database)
	}

	/// Fetch unread count for a single feed.
	public func unreadCount(feedID: String) throws -> Int? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.unreadCount(feedID: feedID, database: database)
	}

	/// Fetch non-zero unread counts for given feedIDs.
	public func unreadCounts(feedIDs: Set<String>) throws -> UnreadCountDictionary {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.unreadCounts(feedIDs: feedIDs, database: database)
	}

	public func unreadCountForToday(feedIDs: Set<String>) throws -> Int? {

		try unreadCount(feedIDs: feedIDs, since: todayCutoffDate())
	}

	public func unreadCount(feedIDs: Set<String>, since: Date) throws -> Int? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.unreadCount(feedIDs: feedIDs, since: since, database: database)
	}

	public func starredAndUnreadCount(feedIDs: Set<String>) throws -> Int? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.starredAndUnreadCount(feedIDs: feedIDs, database: database)
	}

	// MARK: - Saving, Updating, and Deleting Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	public func update(parsedItems: Set<ParsedItem>, feedID: String, deleteOlder: Bool) throws -> ArticleChanges {

		precondition(retentionStyle == .feedBased)
		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.update(parsedItems: parsedItems, feedID: feedID, deleteOlder: deleteOlder, database: database)
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	public func update(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool) throws -> ArticleChanges {

		precondition(retentionStyle == .syncSystem)
		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.update(feedIDsAndItems: feedIDsAndItems, read: defaultRead, database: database)
	}

	/// Delete articles
	public func delete(articleIDs: Set<String>) throws {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.delete(articleIDs: articleIDs, database: database)
	}

	// MARK: - Status

	/// Fetch the articleIDs of unread articles.
	public func unreadArticleIDs() throws -> Set<String>? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.unreadArticleIDs(database: database)
	}

	/// Fetch the articleIDs of starred articles.
	public func starredArticleIDs() throws -> Set<String>? {
		
		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.starredArticleIDs(database: database)
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either (starred) or (newer than the article cutoff date).
	public func articleIDsForStatusesWithoutArticlesNewerThanCutoffDate() throws -> Set<String>? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return  articlesTable.articleIDsForStatusesWithoutArticlesNewerThanCutoffDate(database: database)
	}

	public func mark(articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) throws -> Set<ArticleStatus>? {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.mark(articles: articles, statusKey: statusKey, flag: flag, database: database)
	}

	public func mark(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) throws {

		guard let database else {
			throw DatabaseError.suspended
		}
		articlesTable.mark(articleIDs: articleIDs, statusKey: statusKey, flag: flag, database: database)
	}

	/// Create statuses for specified articleIDs. For existing statuses, don’t do anything.
	/// For newly-created statuses, mark them as read and not-starred.
	public func createStatusesIfNeeded(articleIDs: Set<String>) throws {

		guard let database else {
			throw DatabaseError.suspended
		}
		return articlesTable.createStatusesIfNeeded(articleIDs: articleIDs, database: database)
	}

	// MARK: - Suspend and Resume (for iOS)

	public func suspend() {
#if os(iOS)
		database?.close()
		database = nil
#endif
	}

	public func resume() {
#if os(iOS)
		if database == nil {
			self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		}
#endif
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
	public func cleanupDatabaseAtStartup(subscribedToFeedIDs: Set<String>) throws {

		guard let database else {
			throw DatabaseError.suspended
		}

		if retentionStyle == .syncSystem {
			articlesTable.deleteOldArticles(database: database)
		}
		articlesTable.deleteArticlesNotInSubscribedToFeedIDs(subscribedToFeedIDs, database: database)
		articlesTable.deleteOldStatuses(database: database)
	}
}

// MARK: - Private

private extension ArticlesDatabase {

	static let creationStatements = """
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

	func indexUnindexedArticles() {

		guard let database else {
			return // not an error in this case
		}

		let didIndexArticles = articlesTable.indexUnindexedArticles(database: database)
		if didIndexArticles {
			// Indexing happens in bunches. Continue until there are no more articles to index.
			Task {
				self.indexUnindexedArticles()
			}
		}
	}
}
