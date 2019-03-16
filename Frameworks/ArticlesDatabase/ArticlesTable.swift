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
	private let queue: RSDatabaseQueue
	private let statusesTable: StatusesTable
	private let authorsLookupTable: DatabaseLookupTable
	private let attachmentsLookupTable: DatabaseLookupTable

	private lazy var searchTable: SearchTable = {
		return SearchTable(queue: queue, articlesTable: self)
	}()

	// TODO: update articleCutoffDate as time passes and based on user preferences.
	private var articleCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 3 * 31)!
	private var maximumArticleCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 4 * 31)!

	init(name: String, accountID: String, queue: RSDatabaseQueue) {

		self.name = name
		self.accountID = accountID
		self.queue = queue
		self.statusesTable = StatusesTable(queue: queue)

		let authorsTable = AuthorsTable(name: DatabaseTableName.authors)
		self.authorsLookupTable = DatabaseLookupTable(name: DatabaseTableName.authorsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.authorID, relatedTable: authorsTable, relationshipName: RelationshipName.authors)
		
		let attachmentsTable = AttachmentsTable(name: DatabaseTableName.attachments)
		self.attachmentsLookupTable = DatabaseLookupTable(name: DatabaseTableName.attachmentsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.attachmentID, relatedTable: attachmentsTable, relationshipName: RelationshipName.attachments)
	}

	// MARK: Fetching
	
	func fetchArticles(_ feedID: String) -> Set<Article> {
		
		var articles = Set<Article>()

		queue.fetchSync { (database) in
			articles = self.fetchArticlesForFeedID(feedID, withLimits: true, database: database)
		}

		return articles
	}

	func fetchArticlesAsync(_ feedID: String, withLimits: Bool, _ resultBlock: @escaping ArticleResultBlock) {

		queue.fetch { (database) in

			let articles = self.fetchArticlesForFeedID(feedID, withLimits: withLimits, database: database)

			DispatchQueue.main.async {
				resultBlock(articles)
			}
		}
	}
	
	func fetchUnreadArticles(for feedIDs: Set<String>) -> Set<Article> {

		return fetchUnreadArticles(feedIDs)
	}

	public func fetchTodayArticles(for feedIDs: Set<String>) -> Set<Article> {

		return fetchTodayArticles(feedIDs)
	}

	public func fetchStarredArticles(for feedIDs: Set<String>) -> Set<Article> {

		return fetchStarredArticles(feedIDs)
	}

	func fetchArticlesMatching(_ searchString: String, for feedIDs: Set<String>) -> Set<Article> {
		var articles: Set<Article> = Set<Article>()
		queue.fetchSync { (database) in
			articles = self.fetchArticlesMatching(searchString, database)
		}
		articles = articles.filter{ feedIDs.contains($0.feedID) }
		return articles
	}

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

	// MARK: Updating
	
	func update(_ feedID: String, _ parsedFeed: ParsedFeed, _ completion: @escaping UpdateArticlesWithFeedCompletionBlock) {

		if parsedFeed.items.isEmpty {
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

		let articleIDs = Set(parsedFeed.items.map { $0.articleID })
		
		self.queue.update { (database) in
			
			let statusesDictionary = self.statusesTable.ensureStatusesForArticleIDs(articleIDs, database) //1
			assert(statusesDictionary.count == articleIDs.count)
			
			let allIncomingArticles = Article.articlesWithParsedItems(parsedFeed.items, self.accountID, feedID, statusesDictionary) //2
			if allIncomingArticles.isEmpty {
				self.callUpdateArticlesCompletionBlock(nil, nil, completion)
				return
			}
			
			let incomingArticles = self.filterIncomingArticles(allIncomingArticles) //3
			if incomingArticles.isEmpty {
				self.callUpdateArticlesCompletionBlock(nil, nil, completion)
				return
			}

			let fetchedArticles = self.fetchArticlesForFeedID(feedID, withLimits: false, database: database) //4
			let fetchedArticlesDictionary = fetchedArticles.dictionary()
			
			let newArticles = self.findAndSaveNewArticles(incomingArticles, fetchedArticlesDictionary, database) //5
			let updatedArticles = self.findAndSaveUpdatedArticles(incomingArticles, fetchedArticlesDictionary, database) //6
			
			self.callUpdateArticlesCompletionBlock(newArticles, updatedArticles, completion) //7

			// 8. Update search index.
			var articlesToIndex = Set<Article>()
			if let newArticles = newArticles {
				articlesToIndex.formUnion(newArticles)
			}
			if let updatedArticles = updatedArticles {
				articlesToIndex.formUnion(updatedArticles)
			}
			let articleIDs = articlesToIndex.articleIDs()
			if articleIDs.isEmpty {
				return
			}
			DispatchQueue.main.async() {
				self.searchTable.ensureIndexedArticles(for: articleIDs)
			}
		}
	}

	// MARK: Unread Counts
	
	func fetchUnreadCounts(_ feedIDs: Set<String>, _ completion: @escaping UnreadCountCompletionBlock) {
		
		if feedIDs.isEmpty {
			completion(UnreadCountDictionary())
			return
		}

		var unreadCountDictionary = UnreadCountDictionary()

		queue.fetch { (database) in

			for feedID in feedIDs {
				unreadCountDictionary[feedID] = self.fetchUnreadCount(feedID, database)
			}

			DispatchQueue.main.async() {
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
		
		queue.fetch { (database) in

			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and read=0 and userDeleted=0;"

			var parameters = [Any]()
			parameters += Array(feedIDs) as [Any]
			parameters += [since] as [Any]
			parameters += [since] as [Any]

			let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

			DispatchQueue.main.async() {
				callback(unreadCount)
			}
		}
	}

	func fetchAllUnreadCounts(_ completion: @escaping UnreadCountCompletionBlock) {

		// Returns only where unreadCount > 0.

		let cutoffDate = articleCutoffDate

		queue.fetch { (database) in

			let sql = "select distinct feedID, count(*) from articles natural join statuses where read=0 and userDeleted=0 and (starred=1 or dateArrived>?) group by feedID;"

			guard let resultSet = database.executeQuery(sql, withArgumentsIn: [cutoffDate]) else {
				DispatchQueue.main.async() {
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

			DispatchQueue.main.async() {
				completion(d)
			}
		}
	}

	func fetchStarredAndUnreadCount(_ feedIDs: Set<String>, _ callback: @escaping (Int) -> Void) {

		if feedIDs.isEmpty {
			callback(0)
			return
		}

		queue.fetch { (database) in

			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 and starred=1 and userDeleted=0;"
			let parameters = Array(feedIDs) as [Any]

			let unreadCount = self.numberWithSQLAndParameters(sql, parameters, in: database)

			DispatchQueue.main.async() {
				callback(unreadCount)
			}
		}
	}

	// MARK: Status
	
	func mark(_ articles: Set<Article>, _ statusKey: ArticleStatus.Key, _ flag: Bool) -> Set<ArticleStatus>? {

		return statusesTable.mark(articles.statuses(), statusKey, flag)
	}

	// MARK: Indexing

	func indexUnindexedArticles() {
		queue.fetch { (database) in
			let sql = "select articleID from articles where searchRowID is null limit 500;"
			guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
				return
			}
			let articleIDs = resultSet.mapToSet{ $0.string(forColumn: DatabaseKey.articleID) }
			if articleIDs.isEmpty {
				return
			}
			self.searchTable.ensureIndexedArticles(for: articleIDs)

			DispatchQueue.main.async {
				self.indexUnindexedArticles()
			}
		}
	}
}

// MARK: - Private

private extension ArticlesTable {

	// MARK: Fetching

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
		let attachmentsMap = attachmentsLookupTable.fetchRelatedObjects(for: articleIDs, in: database)

		// 3. Create articles with related objects.

		let articles = databaseArticles.map { (databaseArticle) -> Article in
			return articleWithDatabaseArticle(databaseArticle, authorsMap, attachmentsMap)
		}

		return Set(articles)
	}

	func articleWithDatabaseArticle(_ databaseArticle: DatabaseArticle, _ authorsMap: RelatedObjectsMap?, _ attachmentsMap: RelatedObjectsMap?) -> Article {

		let articleID = databaseArticle.articleID
		let authors = authorsMap?.authors(for: articleID)
		let attachments = attachmentsMap?.attachments(for: articleID)

		return Article(databaseArticle: databaseArticle, accountID: accountID, authors: authors, attachments: attachments)
	}

	func makeDatabaseArticles(with resultSet: FMResultSet) -> Set<DatabaseArticle> {

		let articles = resultSet.mapToSet { (row) -> DatabaseArticle? in

			// The resultSet is a result of a JOIN query with the statuses table,
			// so we can get the statuses at the same time and avoid additional database lookups.

			guard let status = statusesTable.statusWithRow(resultSet) else {
				assertionFailure("Expected status.")
				return nil
			}

			guard let articleID = row.string(forColumn: DatabaseKey.articleID) else {
				assertionFailure("Expected articleID.")
				return nil
			}
			guard let feedID = row.string(forColumn: DatabaseKey.feedID) else {
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

			return DatabaseArticle(articleID: articleID, feedID: feedID, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, status: status)
		}

		return articles
	}

	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject], withLimits: Bool) -> Set<Article> {

		// Don’t fetch articles that shouldn’t appear in the UI. The rules:
		// * Must not be deleted.
		// * Must be either 1) starred or 2) dateArrived must be newer than cutoff date.

		if withLimits {
			let sql = "select * from articles natural join statuses where \(whereClause) and userDeleted=0 and (starred=1 or dateArrived>?);"
			return articlesWithSQL(sql, parameters + [articleCutoffDate as AnyObject], database)
		}
		else {
			let sql = "select * from articles natural join statuses where \(whereClause);"
			return articlesWithSQL(sql, parameters, database)
		}
	}

	func fetchUnreadCount(_ feedID: String, _ database: FMDatabase) -> Int {
		
		// Count only the articles that would appear in the UI.
		// * Must be unread.
		// * Must not be deleted.
		// * Must be either 1) starred or 2) dateArrived must be newer than cutoff date.

		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0 and (starred=1 or dateArrived>?);"
		return numberWithSQLAndParameters(sql, [feedID, articleCutoffDate], in: database)
	}
	
	func fetchArticlesForFeedID(_ feedID: String, withLimits: Bool, database: FMDatabase) -> Set<Article> {

		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [feedID as AnyObject], withLimits: withLimits)
	}

	func fetchUnreadArticles(_ feedIDs: Set<String>) -> Set<Article> {

		if feedIDs.isEmpty {
			return Set<Article>()
		}

		var articles = Set<Article>()

		queue.fetchSync { (database) in

			// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0

			let parameters = feedIDs.map { $0 as AnyObject }
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let whereClause = "feedID in \(placeholders) and read=0"
			articles = self.fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: true)
		}

		return articles
	}

	func fetchTodayArticles(_ feedIDs: Set<String>) -> Set<Article> {

		if feedIDs.isEmpty {
			return Set<Article>()
		}

		var articles = Set<Article>()

		queue.fetchSync { (database) in

			// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and (datePublished > ? || (datePublished is null and dateArrived > ?)
			//
			// datePublished may be nil, so we fall back to dateArrived.

			let startOfToday = NSCalendar.startOfToday()
			let parameters = feedIDs.map { $0 as AnyObject } + [startOfToday as AnyObject, startOfToday as AnyObject]
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let whereClause = "feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and userDeleted = 0"
//			let whereClause = "feedID in \(placeholders) and datePublished > ? and userDeleted = 0"
			articles = self.fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: false)
		}

		return articles
	}

	func fetchStarredArticles(_ feedIDs: Set<String>) -> Set<Article> {

		if feedIDs.isEmpty {
			return Set<Article>()
		}

		var articles = Set<Article>()

		queue.fetchSync { (database) in

			// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and starred = 1 and userDeleted = 0;

			let parameters = feedIDs.map { $0 as AnyObject }
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let whereClause = "feedID in \(placeholders) and starred = 1 and userDeleted = 0"
			articles = self.fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters, withLimits: false)
		}

		return articles
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

	// MARK: Saving Parsed Items
	
	
	func callUpdateArticlesCompletionBlock(_ newArticles: Set<Article>?, _ updatedArticles: Set<Article>?, _ completion: @escaping UpdateArticlesWithFeedCompletionBlock) {
		
		DispatchQueue.main.async {
			completion(newArticles, updatedArticles)
		}
	}
	
	// MARK: Save New Articles

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
		attachmentsLookupTable.saveRelatedObjects(for: databaseObjects, in: database)
	}

	// MARK: Update Existing Articles

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
		updateRelatedObjects(\Article.attachments, updatedArticles, fetchedArticles, attachmentsLookupTable, database)
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
	
	func statusIndicatesArticleIsIgnorable(_ status: ArticleStatus) -> Bool {

		// Ignorable articles: either userDeleted==1 or (not starred and arrival date > 4 months).

		if status.userDeleted {
			return true
		}
		if status.starred {
			return false
		}
		return status.dateArrived < maximumArticleCutoffDate
	}

	func filterIncomingArticles(_ articles: Set<Article>) -> Set<Article> {
		
		// Drop Articles that we can ignore.
		
		return Set(articles.filter{ !statusIndicatesArticleIsIgnorable($0.status) })
	}
}

