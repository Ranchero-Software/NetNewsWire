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
	private var databaseArticlesCache = [String: DatabaseArticle]()

	private lazy var searchTable: SearchTable = {
		return SearchTable(queue: queue, articlesTable: self)
	}()

	// TODO: update articleCutoffDate as time passes and based on user preferences.
	private var articleCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 90)!

	private typealias ArticlesFetchMethod = (FMDatabase) -> Set<Article>

	init(name: String, accountID: String, queue: DatabaseQueue) {

		self.name = name
		self.accountID = accountID
		self.queue = queue
		self.statusesTable = StatusesTable(queue: queue)

		let authorsTable = AuthorsTable(name: DatabaseTableName.authors)
		self.authorsLookupTable = DatabaseLookupTable(name: DatabaseTableName.authorsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.authorID, relatedTable: authorsTable, relationshipName: RelationshipName.authors)
	}

	// MARK: - Fetching Articles for Feed
	
	func fetchArticles(_ webFeedID: String) -> Set<Article> {
		return fetchArticles{ self.fetchArticlesForFeedID(webFeedID, withLimits: true, $0) }
	}

	func fetchArticlesAsync(_ webFeedID: String, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesForFeedID(webFeedID, withLimits: true, $0) }, completion)
	}

	private func fetchArticlesForFeedID(_ webFeedID: String, withLimits: Bool, _ database: FMDatabase) -> Set<Article> {
		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [webFeedID as AnyObject], withLimits: withLimits)
	}

	func fetchArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchArticles(webFeedIDs, $0) }
	}

	func fetchArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticles(webFeedIDs, $0) }, completion)
	}

	private func fetchArticles(_ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders)"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: true)
	}

	// MARK: - Fetching Articles by articleID

	func fetchArticles(articleIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchArticles(articleIDs: articleIDs, $0) }
	}

	func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		return fetchArticlesAsync({ self.fetchArticles(articleIDs: articleIDs, $0) }, completion)
	}

	private func fetchArticles(articleIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		if articleIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let whereClause = "articleID in \(placeholders)"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: false)
	}

	// MARK: - Fetching Unread Articles

	func fetchUnreadArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchUnreadArticles(webFeedIDs, $0) }
	}

	func fetchUnreadArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchUnreadArticles(webFeedIDs, $0) }, completion)
	}

	private func fetchUnreadArticles(_ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders) and read=0"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: true)
	}

	// MARK: - Fetching Today Articles

	func fetchArticlesSince(_ webFeedIDs: Set<String>, _ cutoffDate: Date) -> Set<Article> {
		return fetchArticles{ self.fetchArticlesSince(webFeedIDs, cutoffDate, $0) }
	}

	func fetchArticlesSinceAsync(_ webFeedIDs: Set<String>, _ cutoffDate: Date, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesSince(webFeedIDs, cutoffDate, $0) }, completion)
	}

	private func fetchArticlesSince(_ webFeedIDs: Set<String>, _ cutoffDate: Date, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and (datePublished > ? || (datePublished is null and dateArrived > ?)
		//
		// datePublished may be nil, so we fall back to dateArrived.
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject } + [cutoffDate as AnyObject, cutoffDate as AnyObject]
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and userDeleted = 0"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: false)
	}

	// MARK: - Fetching Starred Articles

	func fetchStarredArticles(_ webFeedIDs: Set<String>) -> Set<Article> {
		return fetchArticles{ self.fetchStarredArticles(webFeedIDs, $0) }
	}

	func fetchStarredArticlesAsync(_ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchStarredArticles(webFeedIDs, $0) }, completion)
	}

	private func fetchStarredArticles(_ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and starred = 1 and userDeleted = 0;
		if webFeedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = webFeedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
		let whereClause = "feedID in \(placeholders) and starred = 1 and userDeleted = 0"
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: false)
		}

	// MARK: - Fetching Search Articles

	func fetchArticlesMatching(_ searchString: String) -> Set<Article> {
		var articles: Set<Article> = Set<Article>()
		guard !queue.isSuspended else {
			return articles
		}
		queue.runInDatabaseSync { (database) in
			articles = self.fetchArticlesMatching(searchString, database)
		}
		return articles
	}

	func fetchArticlesMatching(_ searchString: String, _ webFeedIDs: Set<String>) -> Set<Article> {
		var articles = fetchArticlesMatching(searchString)
		articles = articles.filter{ webFeedIDs.contains($0.webFeedID) }
		return articles
	}

	func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>) -> Set<Article> {
		var articles = fetchArticlesMatching(searchString)
		articles = articles.filter{ articleIDs.contains($0.articleID) }
		return articles
	}

	func fetchArticlesMatchingAsync(_ searchString: String, _ webFeedIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesMatching(searchString, webFeedIDs, $0) }, completion)
	}

	func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetBlock) {
		fetchArticlesAsync({ self.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs, $0) }, completion)
	}

	private func fetchArticlesMatching(_ searchString: String, _ webFeedIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		let articles = fetchArticlesMatching(searchString, database)
		// TODO: include the feedIDs in the SQL rather than filtering here.
		return articles.filter{ webFeedIDs.contains($0.webFeedID) }
	}

	private func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>, _ database: FMDatabase) -> Set<Article> {
		let articles = fetchArticlesMatching(searchString, database)
		// TODO: include the articleIDs in the SQL rather than filtering here.
		return articles.filter{ articleIDs.contains($0.articleID) }
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

	func update(_ webFeedIDsAndItems: [String: Set<ParsedItem>], _ read: Bool, _ completion: @escaping UpdateArticlesCompletionBlock) {
		if webFeedIDsAndItems.isEmpty {
			completion(nil, nil)
			return
		}

		// 1. Ensure statuses for all the incoming articles.
		// 2. Create incoming articles with parsedItems.
		// 3. Ignore incoming articles that are userDeleted || (!starred and really old)
		// 4. Fetch all articles for the feed.
		// 5. Create array of Articles not in database and save them.
		// 6. Create array of updated Articles and save what’s changed.
		// 7. Call back with new and updated Articles.
		// 8. Update search index.

		var articleIDs = Set<String>()
		for (_, parsedItems) in webFeedIDsAndItems {
			articleIDs.formUnion(parsedItems.articleIDs())
		}

		guard !self.queue.isSuspended else {
			self.callUpdateArticlesCompletionBlock(nil, nil, completion)
			return
		}
		
		self.queue.runInTransaction { (database) in
			let statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, read, database) //1
			assert(statusesDictionary.count == articleIDs.count)

			let allIncomingArticles = Article.articlesWithWebFeedIDsAndItems(webFeedIDsAndItems, self.accountID, statusesDictionary) //2
			if allIncomingArticles.isEmpty {
				self.callUpdateArticlesCompletionBlock(nil, nil, completion)
				return
			}

			let incomingArticles = self.filterIncomingArticles(allIncomingArticles) //3
			if incomingArticles.isEmpty {
				self.callUpdateArticlesCompletionBlock(nil, nil, completion)
				return
			}

			let incomingArticleIDs = incomingArticles.articleIDs()
			let fetchedArticles = self.fetchArticles(articleIDs: incomingArticleIDs, database) //4
			let fetchedArticlesDictionary = fetchedArticles.dictionary()

			let newArticles = self.findAndSaveNewArticles(incomingArticles, fetchedArticlesDictionary, database) //5
			let updatedArticles = self.findAndSaveUpdatedArticles(incomingArticles, fetchedArticlesDictionary, database) //6

			self.callUpdateArticlesCompletionBlock(newArticles, updatedArticles, completion) //7

			// 8. Update search index.
			if let newArticles = newArticles {
				self.searchTable.indexNewArticles(newArticles, database)
			}
			if let updatedArticles = updatedArticles {
				self.searchTable.indexUpdatedArticles(updatedArticles, database)
			}
		}
	}

	func ensureStatuses(_ articleIDs: Set<String>, _ defaultRead: Bool, _ statusKey: ArticleStatus.Key, _ flag: Bool, completion: VoidCompletionBlock? = nil) {
		guard !queue.isSuspended else {
			if let handler = completion {
				callVoidCompletionBlock(handler)
			}
			return
		}
		
		queue.runInTransaction { (database) in
			let statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, defaultRead, database)
			let statuses = Set(statusesDictionary.values)
			self.statusesTable.mark(statuses, statusKey, flag, database)
			if let handler = completion {
				callVoidCompletionBlock(handler)
			}
		}
	}

	func fetchStatuses(_ articleIDs: Set<String>, _ createIfNeeded: Bool, _ completion: @escaping (Set<ArticleStatus>?) -> Void) {
		guard !queue.isSuspended else {
			completion(nil)
			return
		}

		queue.runInTransaction { (database) in
			var statusesDictionary = [String: ArticleStatus]()
			if createIfNeeded {
				statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, false, database)
			}
			else {
				statusesDictionary = self.statusesTable.existingStatusesForArticleIDs(articleIDs, database)
			}
			let statuses = Set(statusesDictionary.values)
			DispatchQueue.main.async {
				completion(statuses)
			}
		}
	}

	// MARK: - Unread Counts
	
	func fetchUnreadCounts(_ webFeedIDs: Set<String>, _ completion: @escaping UnreadCountCompletionBlock) {
		if webFeedIDs.isEmpty {
			completion(UnreadCountDictionary())
			return
		}

		var unreadCountDictionary = UnreadCountDictionary()
		guard !queue.isSuspended else {
			completion(unreadCountDictionary)
			return
		}
		
		queue.runInDatabase { (database) in
			for webFeedID in webFeedIDs {
				unreadCountDictionary[webFeedID] = self.fetchUnreadCount(webFeedID, database)
			}

			DispatchQueue.main.async {
				completion(unreadCountDictionary)
			}
		}
	}

	func fetchUnreadCount(_ webFeedIDs: Set<String>, _ since: Date, _ completion: @escaping (Int) -> Void) {
		// Get unread count for today, for instance.

		if webFeedIDs.isEmpty || queue.isSuspended {
			completion(0)
			return
		}
		
		queue.runInDatabase { (database) in
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
			let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and read=0 and userDeleted=0;"

			var parameters = [Any]()
			parameters += Array(webFeedIDs) as [Any]
			parameters += [since] as [Any]
			parameters += [since] as [Any]

			let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

			DispatchQueue.main.async {
				completion(unreadCount)
			}
		}
	}

	func fetchAllUnreadCounts(_ completion: @escaping UnreadCountCompletionBlock) {
		// Returns only where unreadCount > 0.

		let cutoffDate = articleCutoffDate

		guard !queue.isSuspended else {
			completion(UnreadCountDictionary())
			return
		}
		
		queue.runInDatabase { (database) in
			let sql = "select distinct feedID, count(*) from articles natural join statuses where read=0 and userDeleted=0 and (starred=1 or (datePublished > ? or (datePublished is null and dateArrived > ?))) group by feedID;"

			guard let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate, cutoffDate]) else {
				DispatchQueue.main.async {
					completion(UnreadCountDictionary())
				}
				return
			}

			var d = UnreadCountDictionary()
			while resultSet.next() {
				let unreadCount = resultSet.long(forColumnIndex: 1)
				if let webFeedID = resultSet.string(forColumnIndex: 0) {
					d[webFeedID] = unreadCount
				}
			}

			DispatchQueue.main.async {
				completion(d)
			}
		}
	}

	func fetchStarredAndUnreadCount(_ webFeedIDs: Set<String>, _ completion: @escaping (Int) -> Void) {
		if webFeedIDs.isEmpty || queue.isSuspended {
			completion(0)
			return
		}

		queue.runInDatabase { (database) in
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
			let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 and starred=1 and userDeleted=0;"
			let parameters = Array(webFeedIDs) as [Any]

			let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

			DispatchQueue.main.async {
				completion(unreadCount)
			}
		}
	}

	// MARK: - Statuses
	
	func fetchUnreadArticleIDsAsync(_ webFeedIDs: Set<String>, _ completion: @escaping (Set<String>) -> Void) {
		fetchArticleIDsAsync(.read, false, webFeedIDs, completion)
	}

	func fetchStarredArticleIDsAsync(_ webFeedIDs: Set<String>, _ completion: @escaping (Set<String>) -> Void) {
		fetchArticleIDsAsync(.starred, true, webFeedIDs, completion)
	}

	func fetchStarredArticleIDs() -> Set<String> {
		return statusesTable.fetchStarredArticleIDs()
	}
	
	func fetchArticleIDsForStatusesWithoutArticles() -> Set<String> {
		return statusesTable.fetchArticleIDsForStatusesWithoutArticles()
	}
	
	func mark(_ articles: Set<Article>, _ statusKey: ArticleStatus.Key, _ flag: Bool) -> Set<ArticleStatus>? {
		var statuses: Set<ArticleStatus>?
		
		guard !self.queue.isSuspended else {
			return statuses
		}
		
		self.queue.runInTransactionSync { (database) in
			statuses = self.statusesTable.mark(articles.statuses(), statusKey, flag, database)
		}
		
		return statuses
	}

	// MARK: - Indexing

	func indexUnindexedArticles() {
		guard !queue.isSuspended else {
			return
		}
		queue.runInDatabase { (database) in
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
			self.databaseArticlesCache = [String: DatabaseArticle]()
		}
	}

	// MARK: - Cleanup

	/// Delete articles from feeds that are no longer in the current set of subscribed-to feeds.
	/// This deletes from the articles and articleStatuses tables,
	/// and, via a trigger, it also deletes from the search index.
	func deleteArticlesNotInSubscribedToFeedIDs(_ webFeedIDs: Set<String>) {
		if webFeedIDs.isEmpty || queue.isSuspended {
			return
		}
		queue.runInDatabase { (database) in
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
	}
}

// MARK: - Private

private extension ArticlesTable {

	// MARK: - Fetching

	private func fetchArticles(_ fetchMethod: @escaping ArticlesFetchMethod) -> Set<Article> {
		var articles = Set<Article>()
		guard !queue.isSuspended else {
			return articles
		}
		queue.runInDatabaseSync { (database) in
			articles = fetchMethod(database)
		}
		return articles
	}

	private func fetchArticlesAsync(_ fetchMethod: @escaping ArticlesFetchMethod, _ completion: @escaping ArticleSetBlock) {
		guard !queue.isSuspended else {
			completion(Set<Article>())
			return
		}
		queue.runInDatabase { (database) in
			let articles = fetchMethod(database)
			DispatchQueue.main.async {
				completion(articles)
			}
		}
	}

	func articlesWithResultSet(_ resultSet: FMResultSet, _ database: FMDatabase) -> Set<Article> {
		// 1. Create DatabaseArticles without related objects.
		// 2. Then fetch the related objects, given the set of articleIDs.
		// 3. Then create set of Articles with DatabaseArticles and related objects and return it.

		// 1. Create databaseArticles (intermediate representations).

		let databaseArticles = makeDatabaseArticles(with: resultSet)
		if databaseArticles.isEmpty {
			return Set<Article>()
		}
		
		let articleIDs = databaseArticles.articleIDs()

		// 2. Fetch related objects.

		let authorsMap = authorsLookupTable.fetchRelatedObjects(for: articleIDs, in: database)

		// 3. Create articles with related objects.

		let articles = databaseArticles.map { (databaseArticle) -> Article in
			return articleWithDatabaseArticle(databaseArticle, authorsMap)
		}

		return Set(articles)
	}

	func articleWithDatabaseArticle(_ databaseArticle: DatabaseArticle, _ authorsMap: RelatedObjectsMap?) -> Article {

		let articleID = databaseArticle.articleID
		let authors = authorsMap?.authors(for: articleID)

		return Article(databaseArticle: databaseArticle, accountID: accountID, authors: authors)
	}

	func makeDatabaseArticles(with resultSet: FMResultSet) -> Set<DatabaseArticle> {
		let articles = resultSet.mapToSet { (row) -> DatabaseArticle? in

			guard let articleID = row.string(forColumn: DatabaseKey.articleID) else {
				assertionFailure("Expected articleID.")
				return nil
			}

			// Articles are removed from the cache when they’re updated.
			// See saveUpdatedArticles.
			if let databaseArticle = databaseArticlesCache[articleID] {
				return databaseArticle
			}

			// The resultSet is a result of a JOIN query with the statuses table,
			// so we can get the statuses at the same time and avoid additional database lookups.
			guard let status = statusesTable.statusWithRow(resultSet, articleID: articleID) else {
				assertionFailure("Expected status.")
				return nil
			}
			guard let webFeedID = row.string(forColumn: DatabaseKey.feedID) else {
				assertionFailure("Expected feedID.")
				return nil
			}
			guard let uniqueID = row.string(forColumn: DatabaseKey.uniqueID) else {
				assertionFailure("Expected uniqueID.")
				return nil
			}

			let title = row.string(forColumn: DatabaseKey.title)
			let contentHTML = row.string(forColumn: DatabaseKey.contentHTML)
			let contentText = row.string(forColumn: DatabaseKey.contentText)
			let url = row.string(forColumn: DatabaseKey.url)
			let externalURL = row.string(forColumn: DatabaseKey.externalURL)
			let summary = row.string(forColumn: DatabaseKey.summary)
			let imageURL = row.string(forColumn: DatabaseKey.imageURL)
			let bannerImageURL = row.string(forColumn: DatabaseKey.bannerImageURL)
			let datePublished = row.date(forColumn: DatabaseKey.datePublished)
			let dateModified = row.date(forColumn: DatabaseKey.dateModified)

			let databaseArticle = DatabaseArticle(articleID: articleID, webFeedID: webFeedID, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, status: status)
			databaseArticlesCache[articleID] = databaseArticle
			return databaseArticle
		}

		return articles
	}

	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject], withLimits: Bool) -> Set<Article> {
		// Don’t fetch articles that shouldn’t appear in the UI. The rules:
		// * Must not be deleted.
		// * Must be either 1) starred or 2) dateArrived must be newer than cutoff date.

		if withLimits {
			let sql = "select * from articles natural join statuses where \(whereClause) and userDeleted=0 and (starred=1 or (datePublished > ? or (datePublished is null and dateArrived > ?)));"
			return articlesWithSQL(sql, parameters + [articleCutoffDate as AnyObject] + [articleCutoffDate as AnyObject], database)
		}
		else {
			let sql = "select * from articles natural join statuses where \(whereClause);"
			return articlesWithSQL(sql, parameters, database)
		}
	}

	func fetchUnreadCount(_ webFeedID: String, _ database: FMDatabase) -> Int {
		// Count only the articles that would appear in the UI.
		// * Must be unread.
		// * Must not be deleted.
		// * Must be either 1) starred or 2) dateArrived must be newer than cutoff date.

		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0 and (starred=1 or (datePublished > ? or (datePublished is null and dateArrived > ?)));"
		return numberWithSQLAndParameters(sql, [webFeedID, articleCutoffDate, articleCutoffDate], in: database)
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
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: true)
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

	func fetchArticleIDsAsync(_ statusKey: ArticleStatus.Key, _ value: Bool, _ webFeedIDs: Set<String>, _ completion: @escaping (Set<String>) -> Void) {
		guard !queue.isSuspended && !webFeedIDs.isEmpty else {
			completion(Set<String>())
			return
		}
		queue.runInDatabase { database in
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(webFeedIDs.count))!
			var sql = "select articleID from articles natural join statuses where feedID in \(placeholders) and \(statusKey.rawValue)="
			sql += value ? "1" : "0"
			if statusKey != .userDeleted {
				sql += " and userDeleted=0"
			}
			sql += ";"

			let parameters = Array(webFeedIDs) as [Any]

			guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
				DispatchQueue.main.async {
					completion(Set<String>())
				}
				return
			}

			let articleIDs = resultSet.mapToSet{ $0.string(forColumnIndex: 0) }
			DispatchQueue.main.async {
				completion(articleIDs)
			}
		}
	}


	// MARK: - Saving Parsed Items
	
	func callUpdateArticlesCompletionBlock(_ newArticles: Set<Article>?, _ updatedArticles: Set<Article>?, _ completion: @escaping UpdateArticlesCompletionBlock) {
		DispatchQueue.main.async {
			completion(newArticles, updatedArticles)
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
		removeArticlesFromDatabaseArticlesCache(updatedArticles)
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

	func removeArticlesFromDatabaseArticlesCache(_ updatedArticles: Set<Article>) {
		let articleIDs = updatedArticles.articleIDs()
		for articleID in articleIDs {
			databaseArticlesCache[articleID] = nil
		}
	}

	func articleIsIgnorable(_ article: Article) -> Bool {
		// Ignorable articles: either userDeleted==1 or (not starred and arrival date > 4 months).
		if article.status.userDeleted {
			return true
		}
		if article.status.starred {
			return false
		}
		if let datePublished = article.datePublished {
			return datePublished < articleCutoffDate
		}
		return article.status.dateArrived < articleCutoffDate
	}

	func filterIncomingArticles(_ articles: Set<Article>) -> Set<Article> {
		// Drop Articles that we can ignore.
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
