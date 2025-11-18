//
//  ArticlesDatabase.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSDatabase
import RSParser
import Articles

// This file is the entirety of the public API for ArticlesDatabase.framework.
// Everything else is implementation.

public typealias UnreadCountDictionary = [String: Int] // feedID: unreadCount

public struct ArticleChanges: Sendable {
	public let new: Set<Article>?
	public let updated: Set<Article>?
	public let deleted: Set<Article>?

	public init() {
		self.new = Set<Article>()
		self.updated = Set<Article>()
		self.deleted = Set<Article>()
	}

	public init(new: Set<Article>?, updated: Set<Article>?, deleted: Set<Article>?) {
		self.new = new
		self.updated = updated
		self.deleted = deleted
	}
}

@MainActor public final class ArticlesDatabase: Sendable {
	public enum RetentionStyle: Sendable {
		case feedBased // Local and iCloud: article retention is defined by contents of feed
		case syncSystem // Feedbin, Feedly, etc.: article retention is defined by external system
	}

	private let articlesTable: ArticlesTable
	private let queue: DatabaseQueue
	private let operationQueue = MainThreadOperationQueue()
	private let retentionStyle: RetentionStyle
	private let accountID: String

	nonisolated private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArticlesDatabase")

	public init(databaseFilePath: String, accountID: String, retentionStyle: RetentionStyle) {
		Self.logger.debug("Articles Database init \(accountID, privacy: .public)")

		let queue = DatabaseQueue(databasePath: databaseFilePath)
		self.queue = queue
		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, accountID: accountID, queue: queue, retentionStyle: retentionStyle)
		self.retentionStyle = retentionStyle
		self.accountID = accountID

		try! queue.runCreateStatements(ArticlesDatabase.tableCreationStatements)
		queue.runInDatabase { databaseResult in
			Self.logger.debug("ArticlesDatabase: creating tables \(accountID, privacy: .public)")
			let database = databaseResult.database!
			if !self.articlesTable.containsColumn("searchRowID", in: database) {
				database.executeStatements("ALTER TABLE articles add column searchRowID INTEGER;")
			}
			if !self.articlesTable.containsColumn("markdown", in: database) {
				Self.logger.debug("ArticlesDatabase: adding markdown column \(accountID, privacy: .public)")
				database.executeStatements("ALTER TABLE articles add column markdown TEXT;")
			}
			database.executeStatements("CREATE INDEX if not EXISTS articles_searchRowID on articles(searchRowID);")
			database.executeStatements("DROP TABLE if EXISTS tags;DROP INDEX if EXISTS tags_tagName_index;DROP INDEX if EXISTS articles_feedID_index;DROP INDEX if EXISTS statuses_read_index;DROP TABLE if EXISTS attachments;DROP TABLE if EXISTS attachmentsLookup;")
		}

		DispatchQueue.main.async {
			self.articlesTable.indexUnindexedArticles()
		}
	}

	// MARK: - Fetching Articles

	public func fetchArticles(feedID: String) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchArticles(feedID)
	}

	public func fetchArticles(feedIDs: Set<String>) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchArticles(feedIDs)
	}

	public func fetchArticles(articleIDs: Set<String>) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchArticles(articleIDs: articleIDs)
	}

	public func fetchUnreadArticles(feedIDs: Set<String>, limit: Int? = nil) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchUnreadArticles(feedIDs, limit)
	}

	public func fetchTodayArticles(feedIDs: Set<String>, limit: Int? = nil) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchArticlesSince(feedIDs, todayCutoffDate(), limit)
	}

	public func fetchStarredArticles(feedIDs: Set<String>, limit: Int? = nil) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchStarredArticles(feedIDs, limit)
	}

	public func fetchStarredArticlesCount(feedIDs: Set<String>) throws -> Int {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchStarredArticlesCount(feedIDs)
	}

	public func fetchArticlesMatching(searchString: String, feedIDs: Set<String>) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchArticlesMatching(searchString, feedIDs)
	}

	public func fetchArticlesMatchingWithArticleIDs(searchString: String, articleIDs: Set<String>) throws -> Set<Article> {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try articlesTable.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
	}

	// MARK: - Fetching Articles Async

	public func fetchArticlesAsync(feedID: String) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchArticlesAsync(feedID: feedID) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchArticlesAsync(feedIDs: Set<String>) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchArticlesAsync(feedIDs: feedIDs) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchArticlesAsync(articleIDs: Set<String>) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchArticlesAsync(articleIDs: articleIDs) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchUnreadArticlesAsync(feedIDs: Set<String>, limit: Int? = nil) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchUnreadArticlesAsync(feedIDs: feedIDs, limit: limit) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchTodayArticlesAsync(feedIDs: Set<String>, limit: Int? = nil) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchTodayArticlesAsync(feedIDs: feedIDs, limit: limit) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchedStarredArticlesAsync(feedIDs: Set<String>, limit: Int? = nil) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchedStarredArticlesAsync(feedIDs: feedIDs, limit: limit) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchArticlesMatchingAsync(searchString: String, feedIDs: Set<String>) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchArticlesMatchingAsync(searchString: searchString, feedIDs: feedIDs) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchArticlesMatchingWithArticleIDsAsync(searchString: String, articleIDs: Set<String>) async throws -> Set<Article> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchArticlesMatchingWithArticleIDsAsync(searchString: searchString, articleIDs: articleIDs) { result in
				continuation.resume(with: result)
			}
		}
	}

	// MARK: - Unread Counts

	/// Fetch all non-zero unread counts.
	public func fetchAllUnreadCountsAsync() async throws -> UnreadCountDictionary? {
		return try await withCheckedThrowingContinuation { continuation in
			_fetchAllUnreadCounts { result in
				continuation.resume(with: result)
			}
		}
	}

	/// Fetch unread count for a single feed.
	public func fetchUnreadCountAsync(feedID: String) async throws -> Int {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return try await withCheckedThrowingContinuation { continuation in
			_fetchUnreadCounts(feedIDs: Set([feedID])) { result in
				switch result {
				case .success(let unreadCountDictionary):
					if let unreadCount = unreadCountDictionary[feedID] {
						continuation.resume(returning: unreadCount)
					} else {
						continuation.resume(returning: 0)
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Fetch non-zero unread counts for given feedIDs.
	public func fetchUnreadCountsAsync(feedIDs: Set<String>) async throws -> UnreadCountDictionary {
		try await withCheckedThrowingContinuation { continuation in
			_fetchUnreadCounts(feedIDs: feedIDs) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchUnreadCountForTodayAsync(feedIDs: Set<String>) async throws -> Int {
		try await withCheckedThrowingContinuation { continuation in
			_fetchUnreadCount(feedIDs: feedIDs, since: todayCutoffDate()) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchUnreadCountForStarredArticlesAsync(feedIDs: Set<String>) async throws -> Int {
		try await withCheckedThrowingContinuation { continuation in
			_fetchStarredAndUnreadCount(feedIDs: feedIDs) { result in
				continuation.resume(with: result)
			}
		}
	}

	// MARK: - Saving, Updating, and Deleting Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	public func updateAsync(parsedItems: Set<ParsedItem>, feedID: String, deleteOlder: Bool) async throws -> ArticleChanges {
		try await withCheckedThrowingContinuation { continuation in
			_update(parsedItems: parsedItems, feedID: feedID, deleteOlder: deleteOlder) { result in
				continuation.resume(with: result)
			}
		}
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	public func updateAsync(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool) async throws -> ArticleChanges {
		try await withCheckedThrowingContinuation { continuation in
			_update(feedIDsAndItems: feedIDsAndItems, defaultRead: defaultRead) { result in
				continuation.resume(with: result)
			}
		}
	}

	/// Delete articles
	public func deleteAsync(articleIDs: Set<String>) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			_delete(articleIDs: articleIDs) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}

	// MARK: - ArticleIDs

	/// Fetch the articleIDs of unread articles.
	public func fetchUnreadArticleIDsAsync() async throws -> Set<String> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchUnreadArticleIDsAsync { result in
				continuation.resume(with: result)
			}
		}
	}

	public func fetchStarredArticleIDsAsync() async throws -> Set<String> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchStarredArticleIDsAsync { result in
				continuation.resume(with: result)
			}
		}
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either starred or newer than the article cutoff date.
	public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync() async throws -> Set<String> {
		try await withCheckedThrowingContinuation { continuation in
			_fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in
				continuation.resume(with: result)
			}
		}
	}

	// MARK: - Statuses

	public func markAsync(articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws -> Set<ArticleStatus> {
		try await withCheckedThrowingContinuation { continuation in
			_mark(articles: articles, statusKey: statusKey, flag: flag) { result in
				continuation.resume(with: result)
			}
		}
	}

	public func markAndFetchNewAsync(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws -> Set<String> {
		try await withCheckedThrowingContinuation { continuation in
			_markAndFetchNew(articleIDs: articleIDs, statusKey: statusKey, flag: flag) { result in
				continuation.resume(with: result)
			}
		}
	}

	/// Create statuses for specified articleIDs. For existing statuses, don’t do anything.
	/// For newly-created statuses, mark them as read and not-starred.
	public func createStatusesIfNeededAsync(articleIDs: Set<String>) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			_createStatusesIfNeeded(articleIDs: articleIDs) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}

#if os(iOS)
	// MARK: - Suspend and Resume (for iOS)

	/// Cancel current operations and close the database.
	@MainActor public func cancelAndSuspend() {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		cancelOperations()
		suspend()
	}

	/// Close the database and stop running database calls.
	/// Any pending calls will complete first.
	@MainActor public func suspend() {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		operationQueue.suspend()
		queue.suspend()
	}

	/// Open the database and allow for running database calls again.
	@MainActor public func resume() {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		queue.resume()
		operationQueue.resume()
	}
#endif

	// MARK: - Caches

	/// Call to free up some memory. Should be done when the app is backgrounded, for instance.
	/// This does not empty *all* caches — just the ones that are empty-able.
	public func emptyCaches() {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.emptyCaches()
	}

	// MARK: - Cleanup

	/// Calls the various clean-up functions. To be used only at startup.
	///
	/// This prevents the database from growing forever. If we didn’t do this:
	/// 1) The database would grow to an inordinate size, and
	/// 2) the app would become very slow.
	public func cleanupDatabaseAtStartup(subscribedToFeedIDs: Set<String>) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		if retentionStyle == .syncSystem {
			articlesTable.deleteOldArticles()
		}
		articlesTable.deleteArticlesNotInSubscribedToFeedIDs(subscribedToFeedIDs)
		articlesTable.deleteOldStatuses()
	}
}

// MARK: - Private

private extension ArticlesDatabase {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, markdown TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE, searchRowID INTEGER);

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
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		Task { @MainActor in
			operationQueue.cancelAll()
		}
	}
}

// MARK: - Articles Table (Private)

typealias UnreadCountDictionaryCompletionResult = Result<UnreadCountDictionary, Error>
typealias UnreadCountDictionaryCompletionBlock = @Sendable (UnreadCountDictionaryCompletionResult) -> Void

typealias UpdateArticlesResult = Result<ArticleChanges, DatabaseError>
typealias UpdateArticlesCompletionBlock = @Sendable (UpdateArticlesResult) -> Void

typealias SingleUnreadCountResult = Result<Int, DatabaseError>
typealias SingleUnreadCountCompletionBlock = @Sendable (SingleUnreadCountResult) -> Void

typealias ArticleSetResult = Result<Set<Article>, DatabaseError>
typealias ArticleSetResultBlock = @Sendable (ArticleSetResult) -> Void

typealias ArticleIDsResult = Result<Set<String>, Error>
typealias ArticleIDsCompletionBlock = @Sendable (ArticleIDsResult) -> Void

typealias ArticleStatusesResult = Result<Set<ArticleStatus>, DatabaseError>
typealias ArticleStatusesResultBlock = @Sendable (ArticleStatusesResult) -> Void

private extension ArticlesDatabase {

	func _fetchAllUnreadCounts(_ completion: @escaping UnreadCountDictionaryCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		Task { @MainActor in
			let operation = FetchAllUnreadCountsOperation(databaseQueue: queue)
			if let operationName = operation.name {
				operationQueue.cancel(named: operationName)
			}
			operation.completionBlock = { operation in
				let fetchOperation = operation as! FetchAllUnreadCountsOperation
				completion(fetchOperation.result ?? .failure(DatabaseError.isSuspended))
			}
			operationQueue.add(operation)
		}
	}

	func _fetchUnreadCounts(feedIDs: Set<String>, _ completion: @escaping UnreadCountDictionaryCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchUnreadCounts(feedIDs, completion)
	}

	func _fetchUnreadCount(feedIDs: Set<String>, since: Date, completion: @escaping SingleUnreadCountCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchUnreadCount(feedIDs, since, completion)
	}

	func _fetchStarredAndUnreadCount(feedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchStarredAndUnreadCount(feedIDs, completion)
	}

	func _mark(articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleStatusesResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		return articlesTable.mark(articles, statusKey, flag, completion)
	}

	func _markAndFetchNew(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleIDsCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.markAndFetchNew(articleIDs, statusKey, flag, completion)
	}

	func _createStatusesIfNeeded(articleIDs: Set<String>, completion: @escaping DatabaseCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.createStatusesIfNeeded(articleIDs, completion)
	}

	func _fetchArticlesAsync(feedID: String, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticlesAsync(feedID, completion)
	}

	func _fetchArticlesAsync(feedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticlesAsync(feedIDs, completion)
	}

	func _fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping  ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticlesAsync(articleIDs: articleIDs, completion)
	}

	func _fetchUnreadArticlesAsync(feedIDs: Set<String>, limit: Int? = nil, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchUnreadArticlesAsync(feedIDs, limit, completion)
	}

	func _fetchTodayArticlesAsync(feedIDs: Set<String>, limit: Int? = nil, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticlesSinceAsync(feedIDs, todayCutoffDate(), limit, completion)
	}

	func _fetchedStarredArticlesAsync(feedIDs: Set<String>, limit: Int? = nil, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchStarredArticlesAsync(feedIDs, limit, completion)
	}

	func _fetchArticlesMatchingAsync(searchString: String, feedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticlesMatchingAsync(searchString, feedIDs, completion)
	}

	func _fetchArticlesMatchingWithArticleIDsAsync(searchString: String, articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
	}

	func _update(parsedItems: Set<ParsedItem>, feedID: String, deleteOlder: Bool, completion: @escaping UpdateArticlesCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		precondition(retentionStyle == .feedBased)
		articlesTable.update(parsedItems, feedID, deleteOlder, completion)
	}

	func _update(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping UpdateArticlesCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		precondition(retentionStyle == .syncSystem)
		articlesTable.update(feedIDsAndItems, defaultRead, completion)
	}

	func _delete(articleIDs: Set<String>, completion: DatabaseCompletionBlock?) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.delete(articleIDs: articleIDs, completion: completion)
	}

	func _fetchUnreadArticleIDsAsync(completion: @escaping ArticleIDsCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchUnreadArticleIDsAsync(completion)
	}

	func _fetchStarredArticleIDsAsync(completion: @escaping ArticleIDsCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchStarredArticleIDsAsync(completion)
	}

	func _fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {
		Self.logger.debug("ArticlesDatabase: \(#function, privacy: .public) \(self.accountID, privacy: .public)")
		articlesTable.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(completion)
	}
}
