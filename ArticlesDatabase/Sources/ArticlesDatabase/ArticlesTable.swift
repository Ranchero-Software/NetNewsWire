//
//  ArticlesTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/9/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSDatabaseObjC
import RSParser
import Articles

final class ArticlesTable: DatabaseTable {

	let name: String
	private let accountID: String
	private let queue: DatabaseQueue
	private let statusesTable: StatusesTable
	private let authorsLookupTable: DatabaseLookupTable
	private let retentionStyle: ArticlesDatabase.RetentionStyle

	private var articlesCache = [String: Article]()

	private lazy var searchTable: SearchTable = {
		return SearchTable(queue: queue, articlesTable: self)
	}()

	// TODO: update articleCutoffDate as time passes and based on user preferences.
	let articleCutoffDate = Date().bySubtracting(days: 90)

	private typealias ArticlesFetchMethod = (FMDatabase) -> Set<Article>

	init(name: String, accountID: String, queue: DatabaseQueue, retentionStyle: ArticlesDatabase.RetentionStyle) {

		self.name = name
		self.accountID = accountID
		self.queue = queue
		self.statusesTable = StatusesTable(queue: queue)
		self.retentionStyle = retentionStyle
		
		let authorsTable = AuthorsTable(name: DatabaseTableName.authors)
		self.authorsLookupTable = DatabaseLookupTable(name: DatabaseTableName.authorsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.authorID, relatedTable: authorsTable, relationshipName: RelationshipName.authors)
	}

	// MARK: - Fetching Articles for Feed
	
	func fetchArticles(_ webFeedID: String) throws -> Set<Article> {
		return try fetchArticles{ self.fetchArticlesForFeedID(webFeedID, $0) }
	}

	func fetchArticlesAsync(_ webFeedID: String, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchArticlesForFeedID(webFeedID, $0) }, completion)
	}

	func fetchArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try fetchArticles{ self.fetchArticles(webFeedIDs, $0) }
	}

	func fetchArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchArticles(webFeedIDs, $0) }, completion)
	}

	// MARK: - Fetching Articles by articleID

	func fetchArticles(articleIDs: Set<String>) throws -> Set<Article> {
		return try fetchArticles{ self.fetchArticles(articleIDs: articleIDs, $0) }
	}

	func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		return fetchArticlesAsync({ self.fetchArticles(articleIDs: articleIDs, $0) }, completion)
	}

	// MARK: - Fetching Unread Articles

	func fetchUnreadArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try fetchArticles{ self.fetchUnreadArticles(webFeedIDs, $0) }
	}

	func fetchUnreadArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchUnreadArticles(webFeedIDs, $0) }, completion)
	}

	// MARK: - Fetching Today Articles

	func fetchArticlesSince(_ webFeedIDs: Set<String>, _ cutoffDate: Date) throws -> Set<Article> {
		return try fetchArticles{ self.fetchArticlesSince(webFeedIDs, cutoffDate, $0) }
	}

	func fetchArticlesSinceAsync(_ webFeedIDs: Set<String>, _ cutoffDate: Date, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchArticlesSince(webFeedIDs, cutoffDate, $0) }, completion)
	}

	// MARK: - Fetching Starred Articles

	func fetchStarredArticles(_ webFeedIDs: Set<String>) throws -> Set<Article> {
		return try fetchArticles{ self.fetchStarredArticles(webFeedIDs, $0) }
	}

	func fetchStarredArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchStarredArticles(webFeedIDs, $0) }, completion)
	}

	// MARK: - Fetching Search Articles

	func fetchArticlesMatching(_ searchString: String) throws -> Set<Article> {
		var articles: Set<Article> = Set<Article>()
		var error: DatabaseError? = nil
		
		queue.runInDatabaseSync { (databaseResult) in
			switch databaseResult {
			case .success(let database):
				articles = self.fetchArticlesMatching(searchString, database)
			case .failure(let databaseError):
				error = databaseError
			}
		}

		if let error = error {
			throw(error)
		}
		return articles
	}

	func fetchArticlesMatching(_ searchString: String, _ webFeedIDs: Set<String>) throws -> Set<Article> {
		var articles = try fetchArticlesMatching(searchString)
		articles = articles.filter{ webFeedIDs.contains($0.webFeedID) }
		return articles
	}

	func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>) throws -> Set<Article> {
		var articles = try fetchArticlesMatching(searchString)
		articles = articles.filter{ articleIDs.contains($0.articleID) }
		return articles
	}

	func fetchArticlesMatchingAsync(_ searchString: String, _ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchArticlesMatching(searchString, webFeedIDs, $0) }, completion)
	}

	func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync({ self.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs, $0) }, completion)
	}

	// MARK: - Fetching Articles for Indexer
	private func articleSearchInfosQuery(with placeholders: String) -> String {
		return """
        SELECT
            art.articleID,
            art.title,
            art.contentHTML,
            art.contentText,
            art.summary,
            art.searchRowID,
            (SELECT GROUP_CONCAT(name, ' ')
                FROM authorsLookup as autL
                JOIN authors as aut ON autL.authorID = aut.authorID
                WHERE art.articleID = autL.articleID
                GROUP BY autl.articleID) as authors
        FROM articles as art
        WHERE articleID in \(placeholders);
        """
	}

	func fetchArticleSearchInfos(_ articleIDs: Set<String>, in database: FMDatabase) -> Set<ArticleSearchInfo>? {
		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		if let resultSet = database.executeQuery(self.articleSearchInfosQuery(with: placeholders), withArgumentsIn: parameters) {
			return resultSet.mapToSet { (row) -> ArticleSearchInfo? in
				let articleID = row.string(forColumn: DatabaseKey.articleID)!
				let title = row.string(forColumn: DatabaseKey.title)
				let contentHTML = row.string(forColumn: DatabaseKey.contentHTML)
				let contentText = row.string(forColumn: DatabaseKey.contentText)
				let summary = row.string(forColumn: DatabaseKey.summary)
				let authorsNames = row.string(forColumn: DatabaseKey.authors)

				let searchRowIDObject = row.object(forColumnName: DatabaseKey.searchRowID)
				var searchRowID: Int? = nil
				if searchRowIDObject != nil && !(searchRowIDObject is NSNull) {
					searchRowID = Int(row.longLongInt(forColumn: DatabaseKey.searchRowID))
				}

				return ArticleSearchInfo(articleID: articleID, title: title, contentHTML: contentHTML, contentText: contentText, summary: summary, authorsNames: authorsNames, searchRowID: searchRowID)
			}
		}
		return nil
	}

	// MARK: - Updating and Deleting

	func update(_ parsedItems: Set<ParsedItem>, _ webFeedID: String, _ deleteOlder: Bool, _ completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .feedBased)
		if parsedItems.isEmpty {
			callUpdateArticlesCompletionBlock(nil, nil, nil, completion)
			return
		}

		// 1. Ensure statuses for all the incoming articles.
		// 2. Create incoming articles with parsedItems.
		// 3. [Deleted - this step is no longer needed]
		// 4. Fetch all articles for the feed.
		// 5. Create array of Articles not in database and save them.
		// 6. Create array of updated Articles and save what’s changed.
		// 7. Call back with new and updated Articles.
		// 8. Delete Articles in database no longer present in the feed.
		// 9. Update search index.

		self.queue.runInTransaction { (databaseResult) in

			func makeDatabaseCalls(_ database: FMDatabase) {
				let articleIDs = parsedItems.articleIDs()

				let (statusesDictionary, _) = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, false, database) //1
				assert(statusesDictionary.count == articleIDs.count)

				let incomingArticles = Article.articlesWithParsedItems(parsedItems, webFeedID, self.accountID, statusesDictionary) //2
				if incomingArticles.isEmpty {
					self.callUpdateArticlesCompletionBlock(nil, nil, nil, completion)
					return
				}

				let fetchedArticles = self.fetchArticlesForFeedID(webFeedID, database) //4
				let fetchedArticlesDictionary = fetchedArticles.dictionary()

				let newArticles = self.findAndSaveNewArticles(incomingArticles, fetchedArticlesDictionary, database) //5
				let updatedArticles = self.findAndSaveUpdatedArticles(incomingArticles, fetchedArticlesDictionary, database) //6

				// Articles to delete are 1) not starred and 2) older than 30 days and 3) no longer in feed.
				let articlesToDelete: Set<Article>
				if deleteOlder {
					let cutoffDate = Date().bySubtracting(days: 30)
					articlesToDelete = fetchedArticles.filter { (article) -> Bool in
						return !article.status.starred && article.status.dateArrived < cutoffDate && !articleIDs.contains(article.articleID)
					}
				} else {
					articlesToDelete = Set<Article>()
				}

				self.callUpdateArticlesCompletionBlock(newArticles, updatedArticles, articlesToDelete, completion) //7

				self.addArticlesToCache(newArticles)
				self.addArticlesToCache(updatedArticles)

				// 8. Delete articles no longer in feed.
				let articleIDsToDelete = articlesToDelete.articleIDs()
				if !articleIDsToDelete.isEmpty {
					self.removeArticles(articleIDsToDelete, database)
					self.removeArticleIDsFromCache(articleIDsToDelete)
				}

				// 9. Update search index.
				if let newArticles = newArticles {
					self.searchTable.indexNewArticles(newArticles, database)
				}
				if let updatedArticles = updatedArticles {
					self.searchTable.indexUpdatedArticles(updatedArticles, database)
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func update(_ webFeedIDsAndItems: [String: Set<ParsedItem>], _ read: Bool, _ completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .syncSystem)
		if webFeedIDsAndItems.isEmpty {
			callUpdateArticlesCompletionBlock(nil, nil, nil, completion)
			return
		}

		// 1. Ensure statuses for all the incoming articles.
		// 2. Create incoming articles with parsedItems.
		// 3. Ignore incoming articles that are (!starred and read and really old)
		// 4. Fetch all articles for the feed.
		// 5. Create array of Articles not in database and save them.
		// 6. Create array of updated Articles and save what’s changed.
		// 7. Call back with new and updated Articles.
		// 8. Update search index.

		self.queue.runInTransaction { (databaseResult) in

			func makeDatabaseCalls(_ database: FMDatabase) {
				var articleIDs = Set<String>()
				for (_, parsedItems) in webFeedIDsAndItems {
					articleIDs.formUnion(parsedItems.articleIDs())
				}

				let (statusesDictionary, _) = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, read, database) //1
				assert(statusesDictionary.count == articleIDs.count)

				let allIncomingArticles = Article.articlesWithWebFeedIDsAndItems(webFeedIDsAndItems, self.accountID, statusesDictionary) //2
				if allIncomingArticles.isEmpty {
					self.callUpdateArticlesCompletionBlock(nil, nil, nil, completion)
					return
				}

				let incomingArticles = self.filterIncomingArticles(allIncomingArticles) //3
				if incomingArticles.isEmpty {
					self.callUpdateArticlesCompletionBlock(nil, nil, nil, completion)
					return
				}

				let incomingArticleIDs = incomingArticles.articleIDs()
				let fetchedArticles = self.fetchArticles(articleIDs: incomingArticleIDs, database) //4
				let fetchedArticlesDictionary = fetchedArticles.dictionary()

				let newArticles = self.findAndSaveNewArticles(incomingArticles, fetchedArticlesDictionary, database) //5
				let updatedArticles = self.findAndSaveUpdatedArticles(incomingArticles, fetchedArticlesDictionary, database) //6

				self.callUpdateArticlesCompletionBlock(newArticles, updatedArticles, nil, completion) //7

				self.addArticlesToCache(newArticles)
				self.addArticlesToCache(updatedArticles)

				// 8. Update search index.
				if let newArticles = newArticles {
					self.searchTable.indexNewArticles(newArticles, database)
				}
				if let updatedArticles = updatedArticles {
					self.searchTable.indexUpdatedArticles(updatedArticles, database)
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	public func delete(articleIDs: Set<String>, completion: DatabaseCompletionBlock?) {
		self.queue.runInTransaction { (databaseResult) in

			func makeDatabaseCalls(_ database: FMDatabase) {
				self.removeArticles(articleIDs, database)
				DispatchQueue.main.async {
					completion?(nil)
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion?(databaseError)
				}
			}
			
		}
		
	}
	
	// MARK: - Unread Counts
	
	func fetchUnreadCount(_ webFeedIDs: Set<String>, _ since: Date, _ completion: @escaping SingleUnreadCountCompletionBlock) {
		// Get unread count for today, for instance.
		if webFeedIDs.isEmpty {
			completion(.success(0))
			return
		}
		
		queue.runInDatabase { databaseResult in

			func makeDatabaseCalls(_ database: FMDatabase) {
				let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
				let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and read=0;"

				var parameters = [Any]()
				parameters += Array(webFeedIDs) as [Any]
				parameters += [since] as [Any]
				parameters += [since] as [Any]

				let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

				DispatchQueue.main.async {
					completion(.success(unreadCount))
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func fetchStarredAndUnreadCount(_ webFeedIDs: Set<String>, _ completion: @escaping SingleUnreadCountCompletionBlock) {
		if webFeedIDs.isEmpty {
			completion(.success(0))
			return
		}

		queue.runInDatabase { databaseResult in

			func makeDatabaseCalls(_ database: FMDatabase) {
				let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
				let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 and starred=1;"
				let parameters = Array(webFeedIDs) as [Any]

				let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

				DispatchQueue.main.async {
					completion(.success(unreadCount))
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	// MARK: - Statuses
	
	func fetchUnreadArticleIDsAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleIDsCompletionBlock) {
		fetchArticleIDsAsync(.read, false, webFeedIDs, completion)
	}

	func fetchStarredArticleIDsAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleIDsCompletionBlock) {
		fetchArticleIDsAsync(.starred, true, webFeedIDs, completion)
	}

	func fetchStarredArticleIDs() throws -> Set<String> {
		return try statusesTable.fetchStarredArticleIDs()
	}
	
	func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {
		statusesTable.fetchArticleIDsForStatusesWithoutArticlesNewerThan(articleCutoffDate, completion)
	}

	func mark(_ articles: Set<Article>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ completion: @escaping ArticleStatusesResultBlock) {
		self.queue.runInTransaction { databaseResult in
			switch databaseResult {
			case .success(let database):
				let statuses = self.statusesTable.mark(articles.statuses(), statusKey, flag, database)
				DispatchQueue.main.async {
					completion(.success(statuses ?? Set<ArticleStatus>()))
				}
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func markAndFetchNew(_ articleIDs: Set<String>, _ statusKey: ArticleStatus.Key, _ flag: Bool, _ completion: @escaping ArticleIDsCompletionBlock) {
		queue.runInTransaction { databaseResult in
			switch databaseResult {
			case .success(let database):
				let newStatusIDs = self.statusesTable.markAndFetchNew(articleIDs, statusKey, flag, database)
				DispatchQueue.main.async {
					completion(.success(newStatusIDs))
				}
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func createStatusesIfNeeded(_ articleIDs: Set<String>, _ completion: @escaping DatabaseCompletionBlock) {
		queue.runInTransaction { databaseResult in
			switch databaseResult {
			case .success(let database):
				let _ = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, true, database)
				DispatchQueue.main.async {
					completion(nil)
				}
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(databaseError)
				}
			}
		}
	}

	// MARK: - Indexing

	func indexUnindexedArticles() {
		queue.runInDatabase { databaseResult in

			func makeDatabaseCalls(_ database: FMDatabase) {
				let sql = "select articleID from articles where searchRowID is null limit 500;"
				guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
					return
				}
				let articleIDs = resultSet.mapToSet{ $0.string(forColumn: DatabaseKey.articleID) }
				if articleIDs.isEmpty {
					return
				}
				self.searchTable.ensureIndexedArticles(articleIDs, database)

				DispatchQueue.main.async {
					self.indexUnindexedArticles()
				}
			}

			if let database = databaseResult.database {
				makeDatabaseCalls(database)
			}
		}
	}

	// MARK: - Caches

	func emptyCaches() {
		queue.runInDatabase { _ in
			self.articlesCache = [String: Article]()
		}
	}

	// MARK: - Cleanup

	/// Delete articles that we won’t show in the UI any longer
	/// — their arrival date is before our 90-day recency window;
	/// they are read; they are not starred.
	///
	/// Because deleting articles might block the database for too long,
	/// we do this in a careful way: delete articles older than a year,
	/// check to see how much time has passed, then decide whether or not to continue.
	/// Repeat for successively more-recent dates.
	///
	/// Returns `true` if it deleted old articles all the way up to the 90 day cutoff date.
	func deleteOldArticles() {
		precondition(retentionStyle == .syncSystem)

		queue.runInTransaction { databaseResult in
			guard let database = databaseResult.database else {
				return
			}

			func deleteOldArticles(cutoffDate: Date) {
				let sql = "delete from articles where articleID in (select articleID from articles natural join statuses where dateArrived<? and read=1 and starred=0);"
				let parameters = [cutoffDate] as [Any]
				database.executeUpdate(sql, withArgumentsIn: parameters)
			}

			let startTime = Date()
			func tooMuchTimeHasPassed() -> Bool {
				let timeElapsed = Date().timeIntervalSince(startTime)
				return timeElapsed > 2.0
			}

			let dayIntervals = [365, 300, 225, 150]
			for dayInterval in dayIntervals {
				deleteOldArticles(cutoffDate: startTime.bySubtracting(days: dayInterval))
				if tooMuchTimeHasPassed() {
					return
				}
			}
			deleteOldArticles(cutoffDate: self.articleCutoffDate)
		}
	}

	/// Delete old statuses.
	func deleteOldStatuses() {
		queue.runInTransaction { databaseResult in
			guard let database = databaseResult.database else {
				return
			}

			let sql: String
			let cutoffDate: Date
			
			switch self.retentionStyle {
			case .syncSystem:
				sql = "delete from statuses where dateArrived<? and read=1 and starred=0 and articleID not in (select articleID from articles);"
				cutoffDate = Date().bySubtracting(days: 180)
			case .feedBased:
				sql = "delete from statuses where dateArrived<? and starred=0 and articleID not in (select articleID from articles);"
				cutoffDate = Date().bySubtracting(days: 30)
			}

			let parameters = [cutoffDate] as [Any]
			database.executeUpdate(sql, withArgumentsIn: parameters)
		}
	}

	/// Delete articles from feeds that are no longer in the current set of subscribed-to feeds.
	/// This deletes from the articles and articleStatuses tables,
	/// and, via a trigger, it also deletes from the search index.
	func deleteArticlesNotInSubscribedToFeedIDs(_ webFeedIDs: Set<String>) {
		if webFeedIDs.isEmpty {
			return
		}
		queue.runInDatabase { databaseResult in

			func makeDatabaseCalls(_ database: FMDatabase) {
				let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
				let sql = "select articleID from articles where feedID not in \(placeholders);"
				let parameters = Array(webFeedIDs) as [Any]
				guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
					return
				}
				let articleIDs = resultSet.mapToSet{ $0.string(forColumn: DatabaseKey.articleID) }
				if articleIDs.isEmpty {
					return
				}
				self.removeArticles(articleIDs, database)
				self.statusesTable.removeStatuses(articleIDs, database)
			}

			if let database = databaseResult.database {
				makeDatabaseCalls(database)
			}
		}
	}

	/// Mark statuses beyond the 90-day window as read.
	///
	/// This is not intended for wide use: this is part of implementing
	/// the April 2020 retention policy change for feed-based accounts.
	func markOlderStatusesAsRead() {
		queue.runInDatabase { databaseResult in
			guard let database = databaseResult.database else {
				return
			}

			let sql = "update statuses set read = 1 where dateArrived<?;"
			let parameters = [self.articleCutoffDate] as [Any]
			database.executeUpdate(sql, withArgumentsIn: parameters)
		}
	}
}

// MARK: - Private

private extension ArticlesTable {

	// MARK: - Fetching

	private func fetchArticles(_ fetchMethod: @escaping ArticlesFetchMethod) throws -> Set<Article> {
		var articles = Set<Article>()
		var error: DatabaseError? = nil
		queue.runInDatabaseSync { databaseResult in
			switch databaseResult {
			case .success(let database):
				articles = fetchMethod(database)
			case .failure(let databaseError):
				error = databaseError
			}
		}
		if let error = error {
			throw(error)
		}
		return articles
	}

	private func fetchArticlesAsync(_ fetchMethod: @escaping ArticlesFetchMethod, _ completion: @escaping ArticleSetResultBlock) {
		queue.runInDatabase { databaseResult in

			switch databaseResult {
			case .success(let database):
				let articles = fetchMethod(database)
				DispatchQueue.main.async {
					completion(.success(articles))
				}
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func articlesWithResultSet(_ resultSet: FMResultSet, _ database: FMDatabase) -> Set<Article> {
		var cachedArticles = Set<Article>()
		var fetchedArticles = Set<Article>()

		while resultSet.next() {

			guard let articleID = resultSet.string(forColumn: DatabaseKey.articleID) else {
				assertionFailure("Expected articleID.")
				continue
			}

			if let article = articlesCache[articleID] {
				cachedArticles.insert(article)
				continue
			}

			// The resultSet is a result of a JOIN query with the statuses table,
			// so we can get the statuses at the same time and avoid additional database lookups.
			guard let status = statusesTable.statusWithRow(resultSet, articleID: articleID) else {
				assertionFailure("Expected status.")
				continue
			}

			guard let article = Article(accountID: accountID, row: resultSet, status: status) else {
				continue
			}
			fetchedArticles.insert(article)
		}
		resultSet.close()

		if fetchedArticles.isEmpty {
			return cachedArticles
		}

		// Fetch authors for non-cached articles. (Articles from the cache already have authors.)
		let fetchedArticleIDs = fetchedArticles.articleIDs()
		let authorsMap = authorsLookupTable.fetchRelatedObjects(for: fetchedArticleIDs, in: database)
		let articlesWithFetchedAuthors = fetchedArticles.map { (article) -> Article in
			if let authors = authorsMap?.authors(for: article.articleID) {
				return article.byAdding(authors)
			}
			return article
		}

		// Add fetchedArticles to cache, now that they have attached authors.
		for article in articlesWithFetchedAuthors {
			articlesCache[article.articleID] = article
		}

		return cachedArticles.union(articlesWithFetchedAuthors)
	}

	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject]) -> Set<Article> {
		let sql = "select * from articles natural join statuses where \(whereClause);"
		return articlesWithSQL(sql, parameters, database)
	}

	func fetchArticlesMatching(_ searchString: String, _ database: FMDatabase) -> Set<Article> {
		let sql = "select rowid from search where search match ?;"
		let sqlSearchString = sqliteSearchString(with: searchString)
		let searchStringParameters = [sqlSearchString]
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: searchStringParameters) else {
			return Set<Article>()
		}
		let searchRowIDs = resultSet.mapToSet { $0.longLongInt(forColumnIndex: 0) }
		if searchRowIDs.isEmpty {
			return Set<Article>()
		}

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(searchRowIDs.count))!
		let whereClause = "searchRowID in \(placeholders)"
		let parameters: [AnyObject] = Array(searchRowIDs) as [AnyObject]
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func sqliteSearchString(with searchString: String) -> String {
		var s = ""
		searchString.enumerateSubstrings(in: searchString.startIndex..<searchString.endIndex, options: .byWords) { (word, range, enclosingRange, stop) in
			guard let word = word else {
				return
			}
			s += word
			if word != "AND" && word != "OR" {
				s += "*"
			}
			s += " "
		}
		return s
	}

	func articlesWithSQL(_ sql: String, _ parameters: [AnyObject], _ database: FMDatabase) -> Set<Article> {
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return Set<Article>()
		}
		return articlesWithResultSet(resultSet, database)
	}

	func fetchArticleIDsAsync(_ statusKey: ArticleStatus.Key, _ value: Bool, _ webFeedIDs: Set<String>, _ completion: @escaping ArticleIDsCompletionBlock) {
		guard !webFeedIDs.isEmpty else {
			completion(.success(Set<String>()))
			return
		}

		queue.runInDatabase { databaseResult in

			func makeDatabaseCalls(_ database: FMDatabase) {
				let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
				var sql = "select articleID from articles natural join statuses where feedID in \(placeholders) and \(statusKey.rawValue)="
				sql += value ? "1" : "0"
				sql += ";"

				let parameters = Array(webFeedIDs) as [Any]

				guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
					DispatchQueue.main.async {
						completion(.success(Set<String>()))
					}
					return
				}

				let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
				DispatchQueue.main.async {
					completion(.success(articleIDs))
				}
			}

			switch databaseResult {
			case .success(let database):
				makeDatabaseCalls(database)
			case .failure(let databaseError):
				DispatchQueue.main.async {
					completion(.failure(databaseError))
				}
			}
		}
	}

	func fetchArticles(_ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders)"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchUnreadArticles(_ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders) and read=0"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchArticlesForFeedID(_ webFeedID: String, _ database: FMDatabase) -> Set<Article> {
		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [webFeedID as AnyObject])
	}

	func fetchArticles(articleIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		if articleIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let whereClause = "articleID in \(placeholders)"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchArticlesSince(_ webFeedIDs: Set<String>, _ cutoffDate: Date, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and (datePublished > ? || (datePublished is null and dateArrived > ?)
		//
		// datePublished may be nil, so we fall back to dateArrived.
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject } + [cutoffDate as AnyObject, cutoffDate as AnyObject]
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?))"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchStarredArticles(_ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and starred=1;
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders) and starred=1"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
		}

	func fetchArticlesMatching(_ searchString: String, _ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		let articles = fetchArticlesMatching(searchString, database)
		// TODO: include the feedIDs in the SQL rather than filtering here.
		return articles.filter{ webFeedIDs.contains($0.webFeedID) }
	}

	func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		let articles = fetchArticlesMatching(searchString, database)
		// TODO: include the articleIDs in the SQL rather than filtering here.
		return articles.filter{ articleIDs.contains($0.articleID) }
	}

	// MARK: - Saving Parsed Items
	
	func callUpdateArticlesCompletionBlock(_ newArticles: Set<Article>?, _ updatedArticles: Set<Article>?, _ deletedArticles: Set<Article>?, _ completion: @escaping UpdateArticlesCompletionBlock) {
		let articleChanges = ArticleChanges(newArticles: newArticles, updatedArticles: updatedArticles, deletedArticles: deletedArticles)
		DispatchQueue.main.async {
			completion(.success(articleChanges))
		}
	}
	
	// MARK: - Saving New Articles

	func findNewArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article]) -> Set<Article>? {
		let newArticles = Set(incomingArticles.filter { fetchedArticlesDictionary[$0.articleID] == nil })
		return newArticles.isEmpty ? nil : newArticles
	}
	
	func findAndSaveNewArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article], _ database: FMDatabase) -> Set<Article>? { //5
		guard let newArticles = findNewArticles(incomingArticles, fetchedArticlesDictionary) else {
			return nil
		}
		self.saveNewArticles(newArticles, database)
		return newArticles
	}
	
	func saveNewArticles(_ articles: Set<Article>, _ database: FMDatabase) {
		saveRelatedObjectsForNewArticles(articles, database)

		if let databaseDictionaries = articles.databaseDictionaries() {
			insertRows(databaseDictionaries, insertType: .orReplace, in: database)
		}
	}

	func saveRelatedObjectsForNewArticles(_ articles: Set<Article>, _ database: FMDatabase) {
		let databaseObjects = articles.databaseObjects()
		authorsLookupTable.saveRelatedObjects(for: databaseObjects, in: database)
	}

	// MARK: - Updating Existing Articles

	func articlesWithRelatedObjectChanges<T>(_ comparisonKeyPath: KeyPath<Article, Set<T>?>, _ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article]) -> Set<Article> {
		return updatedArticles.filter{ (updatedArticle) -> Bool in
			if let fetchedArticle = fetchedArticles[updatedArticle.articleID] {
				return updatedArticle[keyPath: comparisonKeyPath] != fetchedArticle[keyPath: comparisonKeyPath]
			}
			assertionFailure("Expected to find matching fetched article.");
			return true
		}
	}

	func updateRelatedObjects<T>(_ comparisonKeyPath: KeyPath<Article, Set<T>?>, _ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article], _ lookupTable: DatabaseLookupTable, _ database: FMDatabase) {
		let articlesWithChanges = articlesWithRelatedObjectChanges(comparisonKeyPath, updatedArticles, fetchedArticles)
		if !articlesWithChanges.isEmpty {
			lookupTable.saveRelatedObjects(for: articlesWithChanges.databaseObjects(), in: database)
		}
	}

	func saveUpdatedRelatedObjects(_ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article], _ database: FMDatabase) {
		updateRelatedObjects(\Article.authors, updatedArticles, fetchedArticles, authorsLookupTable, database)
	}

	func findUpdatedArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article]) -> Set<Article>? {
		let updatedArticles = incomingArticles.filter{ (incomingArticle) -> Bool in //6
			if let existingArticle = fetchedArticlesDictionary[incomingArticle.articleID] {
				if existingArticle != incomingArticle {
					return true
				}
			}
			return false
		}

		return updatedArticles.isEmpty ? nil : updatedArticles
	}
	
	func findAndSaveUpdatedArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article], _ database: FMDatabase) -> Set<Article>? { //6
		guard let updatedArticles = findUpdatedArticles(incomingArticles, fetchedArticlesDictionary) else {
			return nil
		}
		saveUpdatedArticles(Set(updatedArticles), fetchedArticlesDictionary, database)
		return updatedArticles
	}
	

	func saveUpdatedArticles(_ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article], _ database: FMDatabase) {
		saveUpdatedRelatedObjects(updatedArticles, fetchedArticles, database)
		
		for updatedArticle in updatedArticles {
			saveUpdatedArticle(updatedArticle, fetchedArticles, database)
		}
	}

	func saveUpdatedArticle(_ updatedArticle: Article, _ fetchedArticles: [String: Article], _ database: FMDatabase) {
		// Only update exactly what has changed in the Article (if anything).
		// Untested theory: this gets us better performance and less database fragmentation.
		
		guard let fetchedArticle = fetchedArticles[updatedArticle.articleID] else {
			assertionFailure("Expected to find matching fetched article.");
			saveNewArticles(Set([updatedArticle]), database)
			return
		}
		guard let changesDictionary = updatedArticle.changesFrom(fetchedArticle), changesDictionary.count > 0 else {
			// Not unexpected. There may be no changes.
			return
		}

		updateRowsWithDictionary(changesDictionary, whereKey: DatabaseKey.articleID, matches: updatedArticle.articleID, database: database)
	}

	func addArticlesToCache(_ articles: Set<Article>?) {
		guard let articles = articles else {
			return
		}
		for article in articles {
			articlesCache[article.articleID] = article
		}
	}

	func removeArticleIDsFromCache(_ articleIDs: Set<String>) {
		for articleID in articleIDs {
			articlesCache[articleID] = nil
		}
	}

	func articleIsIgnorable(_ article: Article) -> Bool {
		if article.status.starred || !article.status.read {
			return false
		}
		return article.status.dateArrived < articleCutoffDate
	}

	func filterIncomingArticles(_ articles: Set<Article>) -> Set<Article> {
		// Drop Articles that we can ignore.
		precondition(retentionStyle == .syncSystem)
		return Set(articles.filter{ !articleIsIgnorable($0) })
	}

	func removeArticles(_ articleIDs: Set<String>, _ database: FMDatabase) {
		deleteRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), in: database)
	}
}

private extension Set where Element == ParsedItem {
	func articleIDs() -> Set<String> {
		return Set<String>(map { $0.articleID })
	}
}
