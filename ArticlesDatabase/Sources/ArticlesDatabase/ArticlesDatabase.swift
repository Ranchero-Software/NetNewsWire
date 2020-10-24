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
public typealias UnreadCountDictionaryCompletionResult = Result<UnreadCountDictionary,DatabaseError>
public typealias UnreadCountDictionaryCompletionBlock = (UnreadCountDictionaryCompletionResult) -> Void

public typealias SingleUnreadCountResult = Result<Int, DatabaseError>
public typealias SingleUnreadCountCompletionBlock = (SingleUnreadCountResult) -> Void

public struct ArticleChanges {
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

public typealias UpdateArticlesResult = Result<ArticleChanges, DatabaseError>
public typealias UpdateArticlesCompletionBlock = (UpdateArticlesResult) -> Void

public typealias ArticleSetResult = Result<Set<Article>, DatabaseError>
public typealias ArticleSetResultBlock = (ArticleSetResult) -> Void

public typealias ArticleIDsResult = Result<Set<String>, DatabaseError>
public typealias ArticleIDsCompletionBlock = (ArticleIDsResult) -> Void

public typealias ArticleStatusesResult = Result<Set<ArticleStatus>, DatabaseError>
public typealias ArticleStatusesResultBlock = (ArticleStatusesResult) -> Void

public final class ArticlesDatabase {

	public enum RetentionStyle {
		case feedBased // Local and iCloud: article retention is defined by contents of feed
		case syncSystem // Feedbin, Feedly, etc.: article retention is defined by external system
	}

	private let articlesTable: ArticlesTable
	private let queue: DatabaseQueue
	private let operationQueue = MainThreadOperationQueue()
	private let retentionStyle: RetentionStyle

	public init(databaseFilePath: String, accountID: String, retentionStyle: RetentionStyle) {
		let queue = DatabaseQueue(databasePath: databaseFilePath)
		self.queue = queue
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue, retentionStyle: retentionStyle)
		self.retentionStyle = retentionStyle

		try! queue.runCreateStatements(ArticlesDatabase.tableCreationStatements)
		queue.runInDatabase { databaseResult in
			let database = databaseResult.database!
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

	public func fetchArticles(_ webFeedID: String) throws -> Set<Article> {
		return try articlesTable.fetchArticles(webFeedID)
	}
	
	public func fetchArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchArticles(webFeedIDs)
	}

	public func fetchArticles(articleIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchArticles(articleIDs: articleIDs)
	}

	public func fetchUnreadArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchUnreadArticles(webFeedIDs)
	}

	public func fetchTodayArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchArticlesSince(webFeedIDs, todayCutoffDate())
	}

	public func fetchStarredArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchStarredArticles(webFeedIDs)
	}

	public func fetchArticlesMatching(_ searchString: String, _ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchArticlesMatching(searchString, webFeedIDs)
	}

	public func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>) throws -> Set<Article> {
		return try articlesTable.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
	}

	// MARK: - Fetching Articles Async

	public func fetchArticlesAsync(_ webFeedID: String, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchArticlesAsync(webFeedID, completion)
	}

	public func fetchArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchArticlesAsync(webFeedIDs, completion)
	}

	public func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping  ArticleSetResultBlock) {
		articlesTable.fetchArticlesAsync(articleIDs: articleIDs, completion)
	}

	public func fetchUnreadArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchUnreadArticlesAsync(webFeedIDs, completion)
	}

	public func fetchTodayArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchArticlesSinceAsync(webFeedIDs, todayCutoffDate(), completion)
	}

	public func fetchedStarredArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchStarredArticlesAsync(webFeedIDs, completion)
	}

	public func fetchArticlesMatchingAsync(_ searchString: String, _ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchArticlesMatchingAsync(searchString, webFeedIDs, completion)
	}

	public func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		articlesTable.fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
	}

	// MARK: - Unread Counts

	/// Fetch all non-zero unread counts.
	public func fetchAllUnreadCounts(_ completion: @escaping UnreadCountDictionaryCompletionBlock) {
		let operation = FetchAllUnreadCountsOperation(databaseQueue: queue)
		operationQueue.cancelOperations(named: operation.name!)
		operation.completionBlock = { operation in
			let fetchOperation = operation as! FetchAllUnreadCountsOperation
			completion(fetchOperation.result)
		}
		operationQueue.add(operation)
	}

	/// Fetch unread count for a single feed.
	public func fetchUnreadCount(_ webFeedID: String, _ completion: @escaping SingleUnreadCountCompletionBlock) {
		let operation = FetchFeedUnreadCountOperation(webFeedID: webFeedID, databaseQueue: queue, cutoffDate: articlesTable.articleCutoffDate)
		operation.completionBlock = { operation in
			let fetchOperation = operation as! FetchFeedUnreadCountOperation
			completion(fetchOperation.result)
		}
		operationQueue.add(operation)
	}

	/// Fetch non-zero unread counts for given webFeedIDs.
	public func fetchUnreadCounts(for webFeedIDs: Set<String>, _ completion: @escaping UnreadCountDictionaryCompletionBlock) {
		let operation = FetchUnreadCountsForFeedsOperation(webFeedIDs: webFeedIDs, databaseQueue: queue)
		operation.completionBlock = { operation in
			let fetchOperation = operation as! FetchUnreadCountsForFeedsOperation
			completion(fetchOperation.result)
		}
		operationQueue.add(operation)
	}

	public func fetchUnreadCountForToday(for webFeedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {
		fetchUnreadCount(for: webFeedIDs, since: todayCutoffDate(), completion: completion)
	}

	public func fetchUnreadCount(for webFeedIDs: Set<String>, since: Date, completion: @escaping SingleUnreadCountCompletionBlock) {
		articlesTable.fetchUnreadCount(webFeedIDs, since, completion)
	}

	public func fetchStarredAndUnreadCount(for webFeedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {
		articlesTable.fetchStarredAndUnreadCount(webFeedIDs, completion)
	}

	// MARK: - Saving, Updating, and Deleting Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	public func update(with parsedItems: Set<ParsedItem>, webFeedID: String, deleteOlder: Bool, completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .feedBased)
		articlesTable.update(parsedItems, webFeedID, deleteOlder, completion)
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	public func update(webFeedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .syncSystem)
		articlesTable.update(webFeedIDsAndItems, defaultRead, completion)
	}

	/// Delete articles
	public func delete(articleIDs: Set<String>, completion: DatabaseCompletionBlock?) {
		articlesTable.delete(articleIDs: articleIDs, completion: completion)
	}

	// MARK: - Status

	/// Fetch the articleIDs of unread articles in feeds specified by webFeedIDs.
	public func fetchUnreadArticleIDsAsync(webFeedIDs: Set<String>, completion: @escaping ArticleIDsCompletionBlock) {
		articlesTable.fetchUnreadArticleIDsAsync(webFeedIDs, completion)
	}
	
	/// Fetch the articleIDs of starred articles in feeds specified by webFeedIDs.
	public func fetchStarredArticleIDsAsync(webFeedIDs: Set<String>, completion: @escaping ArticleIDsCompletionBlock) {
		articlesTable.fetchStarredArticleIDsAsync(webFeedIDs, completion)
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either (starred) or (newer than the article cutoff date).
	public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {
		articlesTable.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(completion)
	}

	public func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleStatusesResultBlock) {
		return articlesTable.mark(articles, statusKey, flag, completion)
	}

	public func markAndFetchNew(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleIDsCompletionBlock) {
		articlesTable.markAndFetchNew(articleIDs, statusKey, flag, completion)
	}

	/// Create statuses for specified articleIDs. For existing statuses, don’t do anything.
	/// For newly-created statuses, mark them as read and not-starred.
	public func createStatusesIfNeeded(articleIDs: Set<String>, completion: @escaping DatabaseCompletionBlock) {
		articlesTable.createStatusesIfNeeded(articleIDs, completion)
	}

#if os(iOS)
	// MARK: - Suspend and Resume (for iOS)

	/// Cancel current operations and close the database.
	public func cancelAndSuspend() {
		cancelOperations()
		suspend()
	}

	/// Close the database and stop running database calls.
	/// Any pending calls will complete first.
	public func suspend() {
		operationQueue.suspend()
		queue.suspend()
	}

	/// Open the database and allow for running database calls again.
	public func resume() {
		queue.resume()
		operationQueue.resume()
	}
#endif
	
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

	// MARK: - Operations

	func cancelOperations() {
		operationQueue.cancelAllOperations()
	}
}
