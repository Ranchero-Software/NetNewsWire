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
	
	func fetchArticles(_ feedID: String) -> Set<Article> {
		return fetchArticles{ self.fetchArticlesForFeedID(feedID, $0) }
	}

	func fetchArticlesAsync(_ feedID: String, _ callback: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesForFeedID(feedID, $0) }, callback)
	}

	// MARK: - Fetching Articles by articleID

	func fetchArticles(articleIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchArticles(articleIDs: articleIDs, $0) }
	}

	func fetchArticlesAsync(articleIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		return fetchArticlesAsync({ self.fetchArticles(articleIDs: articleIDs, $0) }, callback)
	}

	// MARK: - Fetching Unread Articles

	func fetchUnreadArticles(_ feedIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchUnreadArticles(feedIDs, $0) }
	}

	func fetchUnreadArticlesAsync(_ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchUnreadArticles(feedIDs, $0) }, callback)
	}

	// MARK: - Fetching Today Articles

	func fetchArticlesSince(_ feedIDs: Set<String>, _ cutoffDate: Date) -> Set<Article> {
		return fetchArticles{ self.fetchArticlesSince(feedIDs, cutoffDate, $0) }
	}

	func fetchArticlesSinceAsync(_ feedIDs: Set<String>, _ cutoffDate: Date, _ callback: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesSince(feedIDs, cutoffDate, $0) }, callback)
	}

	// MARK: - Fetching Starred Articles

	func fetchStarredArticles(_ feedIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchStarredArticles(feedIDs, $0) }
	}

	func fetchStarredArticlesAsync(_ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchStarredArticles(feedIDs, $0) }, callback)
	}

	// MARK: - Fetching Search Articles

	func fetchArticlesMatching(_ searchString: String, _ feedIDs: Set<String>) -> Set<Article> {
		var articles: Set<Article> = Set<Article>()
		queue.runInDatabaseSync { (database) in
			articles = self.fetchArticlesMatching(searchString, database)
		}
		articles = articles.filter{ feedIDs.contains($0.feedID) }
		return articles
	}

	func fetchArticlesMatchingAsync(_ searchString: String, _ feedIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesMatching(searchString, feedIDs, $0) }, callback)
	}

	private func fetchArticlesMatching(_ searchString: String, _ feedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
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
		let articles = fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
		// TODO: include the feedIDs in the SQL rather than filtering here.
		return articles.filter{ feedIDs.contains($0.feedID) }
	}

	// MARK: - Fetching Articles for Indexer

	func fetchArticleSearchInfos(_ articleIDs: Set<String>, in database: FMDatabase) -> Set<ArticleSearchInfo>? {
		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let sql = "select articleID, title, contentHTML, contentText, summary, searchRowID from articles where articleID in \(placeholders);";

		if let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) {
			return resultSet.mapToSet { (row) -> ArticleSearchInfo? in
				let articleID = row.string(forColumn: DatabaseKey.articleID)!
				let title = row.string(forColumn: DatabaseKey.title)
				let contentHTML = row.string(forColumn: DatabaseKey.contentHTML)
				let contentText = row.string(forColumn: DatabaseKey.contentText)
				let summary = row.string(forColumn: DatabaseKey.summary)

				let searchRowIDObject = row.object(forColumnName: DatabaseKey.searchRowID)
				var searchRowID: Int? = nil
				if searchRowIDObject != nil && !(searchRowIDObject is NSNull) {
					searchRowID = Int(row.longLongInt(forColumn: DatabaseKey.searchRowID))
				}

				return ArticleSearchInfo(articleID: articleID, title: title, contentHTML: contentHTML, contentText: contentText, summary: summary, searchRowID: searchRowID)
			}
		}
		return nil
	}

	// MARK: - Updating

	func update(_ parsedItems: Set<ParsedItem>, _ webFeedID: String, _ completion: @escaping UpdateArticlesCompletionBlock) {
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

		self.queue.runInTransaction { database in

			let articleIDs = parsedItems.articleIDs()

			let statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, false, database) //1
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
			let cutoffDate = Date().bySubtracting(days: 30)
			let articlesToDelete = fetchedArticles.filter { (article) -> Bool in
				return !article.status.starred && article.status.dateArrived < cutoffDate && !articleIDs.contains(article.articleID)
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
	}

	func update(_ feedIDsAndItems: [String: Set<ParsedItem>], _ read: Bool, _ completion: @escaping UpdateArticlesCompletionBlock) {
		precondition(retentionStyle == .syncSystem)
		if feedIDsAndItems.isEmpty {
			callUpdateArticlesCompletionBlock(nil, nil, nil, completion)
			return
		}

		// 1. Ensure statuses for all the incoming articles.
		// 2. Create incoming articles with parsedItems.
		// 3. Ignore incoming articles that are (!starred and really old)
		// 4. Fetch all articles for the feed.
		// 5. Create array of Articles not in database and save them.
		// 6. Create array of updated Articles and save what’s changed.
		// 7. Call back with new and updated Articles.
		// 8. Update search index.

		var articleIDs = Set<String>()
		for (_, parsedItems) in feedIDsAndItems {
			articleIDs.formUnion(parsedItems.articleIDs())
		}

		self.queue.runInTransaction { (database) in
			let statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, read, database) //1
			assert(statusesDictionary.count == articleIDs.count)

			let allIncomingArticles = Article.articlesWithFeedIDsAndItems(feedIDsAndItems, self.accountID, statusesDictionary) //2
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
	}

	func ensureStatuses(_ articleIDs: Set<String>, _ defaultRead: Bool, _ statusKey: ArticleStatus.Key, _ flag: Bool) {
		self.queue.runInTransaction { (database) in
			let statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, defaultRead, database)
			let statuses = Set(statusesDictionary.values)
			self.statusesTable.mark(statuses, statusKey, flag, database)
		}
	}

	// MARK: - Unread Counts
	
	func fetchUnreadCounts(_ feedIDs: Set<String>, _ completion: @escaping UnreadCountCompletionBlock) {
		if feedIDs.isEmpty {
			completion(UnreadCountDictionary())
			return
		}

		var unreadCountDictionary = UnreadCountDictionary()

		queue.runInDatabase { (database) in
			for feedID in feedIDs {
				unreadCountDictionary[feedID] = self.fetchUnreadCount(feedID, database)
			}

			DispatchQueue.main.async {
				completion(unreadCountDictionary)
			}
		}
	}

	func fetchUnreadCount(_ feedIDs: Set<String>, _ since: Date, _ callback: @escaping (Int) -> Void) {
		// Get unread count for today, for instance.

		if feedIDs.isEmpty {
			callback(0)
			return
		}
		
		queue.runInDatabase { (database) in
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and read=0;"

			var parameters = [Any]()
			parameters += Array(feedIDs) as [Any]
			parameters += [since] as [Any]
			parameters += [since] as [Any]

			let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

			DispatchQueue.main.async {
				callback(unreadCount)
			}
		}
	}

	func fetchAllUnreadCounts(_ completion: @escaping UnreadCountCompletionBlock) {
		// Returns only where unreadCount > 0.

		let cutoffDate = articleCutoffDate

		queue.runInDatabase { (database) in
			let sql = "select distinct feedID, count(*) from articles natural join statuses where read=0 group by feedID;"

			guard let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate]) else {
				DispatchQueue.main.async {
					completion(UnreadCountDictionary())
				}
				return
			}

			var d = UnreadCountDictionary()
			while resultSet.next() {
				let unreadCount = resultSet.long(forColumnIndex: 1)
				if let feedID = resultSet.string(forColumnIndex: 0) {
					d[feedID] = unreadCount
				}
			}

			DispatchQueue.main.async {
				completion(d)
			}
		}
	}

	func fetchStarredAndUnreadCount(_ feedIDs: Set<String>, _ callback: @escaping (Int) -> Void) {
		if feedIDs.isEmpty {
			callback(0)
			return
		}

		queue.runInDatabase { (database) in
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 and starred=1;"
			let parameters = Array(feedIDs) as [Any]

			let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

			DispatchQueue.main.async {
				callback(unreadCount)
			}
		}
	}

	// MARK: - Statuses
	
	func fetchUnreadArticleIDs() -> Set<String>{
		return statusesTable.fetchUnreadArticleIDs()
	}
	
	func fetchStarredArticleIDs() -> Set<String> {
		return statusesTable.fetchStarredArticleIDs()
	}
	
	func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate() -> Set<String> {
		return statusesTable.fetchArticleIDsForStatusesWithoutArticlesNewerThan(articleCutoffDate)
	}
	
	func mark(_ articles: Set<Article>, _ statusKey: ArticleStatus.Key, _ flag: Bool) -> Set<ArticleStatus>? {
		var statuses: Set<ArticleStatus>?
		self.queue.runInTransactionSync { (database) in
			statuses = self.statusesTable.mark(articles.statuses(), statusKey, flag, database)
		}
		return statuses
	}

	// MARK: - Indexing

	func indexUnindexedArticles() {
		queue.runInTransaction { (database) in
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

		queue.runInTransaction { database in
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
		queue.runInTransaction { database in
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
	func deleteArticlesNotInSubscribedToFeedIDs(_ feedIDs: Set<String>) {
		if feedIDs.isEmpty {
			return
		}
		queue.runInTransaction { (database) in
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let sql = "select articleID from articles where feedID not in \(placeholders);"
			let parameters = Array(feedIDs) as [Any]
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
	}

	/// Mark statuses beyond the 90-day window as read.
	///
	/// This is not intended for wide use: this is part of implementing
	/// the April 2020 retention policy change for feed-based accounts.
	func markOlderStatusesAsRead() {
		queue.runInTransaction { database in
			let sql = "update statuses set read = 1 where dateArrived<?;"
			let parameters = [self.articleCutoffDate] as [Any]
			database.executeUpdate(sql, withArgumentsIn: parameters)
		}
	}
}

// MARK: - Private

private extension ArticlesTable {

	// MARK: - Fetching

	private func fetchArticles(_ fetchMethod: @escaping ArticlesFetchMethod) -> Set<Article> {
		var articles = Set<Article>()
		queue.runInDatabaseSync { (database) in
			articles = fetchMethod(database)
		}
		return articles
	}

	private func fetchArticlesAsync(_ fetchMethod: @escaping ArticlesFetchMethod, _ callback: @escaping ArticleSetBlock) {
		queue.runInDatabase { (database) in
			let articles = fetchMethod(database)
			DispatchQueue.main.async {
				callback(articles)
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

	func fetchUnreadCount(_ feedID: String, _ database: FMDatabase) -> Int {
		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0;"
		return numberWithSQLAndParameters(sql, [feedID, articleCutoffDate], in: database)
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
			if s != "AND" && s != "OR" {
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

	func fetchUnreadArticles(_ feedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0
		if feedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = feedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let whereClause = "feedID in \(placeholders) and read=0"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchArticlesForFeedID(_ feedID: String, _ database: FMDatabase) -> Set<Article> {
		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [feedID as AnyObject])
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

	func fetchArticlesSince(_ feedIDs: Set<String>, _ cutoffDate: Date, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and (datePublished > ? || (datePublished is null and dateArrived > ?)
		//
		// datePublished may be nil, so we fall back to dateArrived.
		if feedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = feedIDs.map { $0 as AnyObject } + [cutoffDate as AnyObject, cutoffDate as AnyObject]
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let whereClause = "feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?))"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchStarredArticles(_ feedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and starred = 1;
		if feedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = feedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let whereClause = "feedID in \(placeholders) and starred=1"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
		}

	// MARK: - Saving Parsed Items
	
	func callUpdateArticlesCompletionBlock(_ newArticles: Set<Article>?, _ updatedArticles: Set<Article>?, _ deletedArticles: Set<Article>?, _ completion: @escaping UpdateArticlesCompletionBlock) {
		let articleChanges = ArticleChanges(newArticles: newArticles, updatedArticles: updatedArticles, deletedArticles: deletedArticles)
		DispatchQueue.main.async {
			completion(articleChanges)
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
