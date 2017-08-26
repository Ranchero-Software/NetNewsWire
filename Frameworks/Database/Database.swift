//
//  Database.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSParser
import Data

public typealias ArticleResultBlock = (Set<Article>) -> Void
public typealias UnreadCountTable = [String: Int] // feedID: unreadCount
public typealias UnreadCountCompletionBlock = (UnreadCountTable) -> Void //feedID: unreadCount

public final class Database {

	private let queue: RSDatabaseQueue
	private let databaseFile: String
	private let articlesTable: ArticlesTable
	private var articleArrivalCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 3 * 31)!
	private let minimumNumberOfArticles = 10
	private weak var delegate: AccountDelegate?
	private weak var account: Account?

	public init(databaseFile: String, delegate: AccountDelegate, account: Account) {

		self.delegate = delegate
		self.account = account
		self.databaseFile = databaseFile
		self.queue = RSDatabaseQueue(filepath: databaseFile, excludeFromBackup: false)

		self.articlesTable = ArticlesTable(name: DatabaseTableName.articles, account: account, queue: queue)

		let createStatementsPath = Bundle(for: type(of: self)).path(forResource: "CreateStatements", ofType: "sql")!
		let createStatements = try! NSString(contentsOfFile: createStatementsPath, encoding: String.Encoding.utf8.rawValue)
		queue.createTables(usingStatements: createStatements as String)
		queue.vacuumIfNeeded()
	}

	// MARK: - Fetching Articles

	public func fetchArticles(for feed: Feed) -> Set<Article> {

		return articlesTable.fetchArticles(feed)
		
//		return Set<Article>() // TODO
//		var fetchedArticles = Set<Article>()
//		let feedID = feed.feedID
//
//		queue.fetchSync { (database: FMDatabase!) -> Void in
//
//			fetchedArticles = self.fetchArticlesForFeedID(feedID, database: database)
//		}
//
//		let articles = articleCache.uniquedArticles(fetchedArticles, statusesTable: statusesTable)
//		return filteredArticles(articles, feedCounts: [feed.feedID: fetchedArticles.count])
	}

	public func fetchArticlesAsync(for feed: Feed, _ resultBlock: @escaping ArticleResultBlock) {

		articlesTable.fetchArticlesAsync(feed, resultBlock)
		
//		let feedID = feed.feedID
//
//		queue.fetch { (database: FMDatabase!) -> Void in
//
//			let fetchedArticles = self.fetchArticlesForFeedID(feedID, database: database)
//
//			DispatchQueue.main.async() { () -> Void in
//
//				let articles = self.articleCache.uniquedArticles(fetchedArticles, statusesTable: self.statusesTable)
//				let filteredArticles = self.filteredArticles(articles, feedCounts: [feed.feedID: fetchedArticles.count])
//				resultBlock(filteredArticles)
//			}
//		}
	}

	public func fetchUnreadArticles(for folder: Folder) -> Set<Article> {
		
		return articlesTable.fetchUnreadArticles(folder.flattenedFeeds())
	}

	// MARK: - Unread Counts
	
	
	public func fetchUnreadCounts(for feeds: Set<Feed>, completion: @escaping UnreadCountCompletionBlock) {
		
		return articlesTable.fetchUnreadCounts(feeds, completion)
//		let feedIDs = feeds.feedIDs()
//
//		queue.fetch { (database: FMDatabase!) -> Void in
//
//			var unreadCounts = UnreadCountTable()
//			for oneFeedID in feedIDs {
//				unreadCounts[oneFeedID] = self.unreadCount(oneFeedID, database)
//			}
//
//			DispatchQueue.main.async() {
//				completion(unreadCounts)
//			}
//		}
	}

	// MARK: - Updating Articles

	public func update(feed: Feed, parsedFeed: ParsedFeed, completion: @escaping RSVoidCompletionBlock) {

		return articlesTable.update(feed, parsedFeed, completion)
		
//		if parsedFeed.items.isEmpty {
//			completionHandler()
//			return
//		}
//
//		let parsedArticlesDictionary = self.articlesDictionary(parsedFeed.items as NSSet) as! [String: ParsedItem]
//
//		fetchArticlesForFeedAsync(feed) { (articles) -> Void in
//
//			let articlesDictionary = self.articlesDictionary(articles as NSSet) as! [String: Article]
//			self.updateArticles(articlesDictionary, parsedArticles: parsedArticlesDictionary, feed: feed, completionHandler: completionHandler)
//		}
	}
	
	// MARK: - Status
	
	public func mark(_ articles: Set<Article>, statusKey: String, flag: Bool) {
		
		articlesTable.mark(articles, statusKey, flag)
//		statusesTable.markArticles(articles, statusKey: statusKey, flag: flag)
	}
}

// MARK: - Private

private extension Database {
	
	
	//	func feedIDCountDictionariesWithResultSet(_ resultSet: FMResultSet) -> [String: Int] {
	//
	//		var counts = [String: Int]()
	//
	//		while (resultSet.next()) {
	//
	//			if let oneFeedID = resultSet.string(forColumnIndex: 0) {
	//				let count = resultSet.int(forColumnIndex: 1)
	//				counts[oneFeedID] = Int(count)
	//			}
	//		}
	//
	//		return counts
	//	}

	//	func countsForAllFeeds(_ database: FMDatabase) -> [String: Int] {
	//
	//		let sql = "select distinct feedID, count(*) as count from articles group by feedID;"
	//
	//		if let resultSet = database.executeQuery(sql, withArgumentsIn: []) {
	//			return feedIDCountDictionariesWithResultSet(resultSet)
	//		}
	//
	//		return [String: Int]()
	//	}

	//	func countsForFeedIDs(_ feedIDs: [String], _ database: FMDatabase) -> [String: Int] {
	//
	//		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
	//		let sql = "select distinct feedID, count(*) from articles where feedID in \(placeholders) group by feedID;"
	//		logSQL(sql)
	//
	//		if let resultSet = database.executeQuery(sql, withArgumentsIn: feedIDs) {
	//			return feedIDCountDictionariesWithResultSet(resultSet)
	//		}
	//
	//		return [String: Int]()
	//
	//	}
	

	//	func fetchUnreadArticlesForFeedIDs(_ feedIDs: [String]) -> Set<Article> {
	//
	//		if feedIDs.isEmpty {
	//			return Set<Article>()
	//		}
	//
	//		var fetchedArticles = Set<Article>()
	//		var counts = [String: Int]()
	//
	//		queue.fetchSync { (database: FMDatabase!) -> Void in
	//
	//			counts = self.countsForFeedIDs(feedIDs, database)
	//
	//			// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read = 0
	//
	//			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
	//			let sql = "select * from articles natural join statuses where feedID in \(placeholders) and read=0;"
	//			logSQL(sql)
	//
	//			if let resultSet = database.executeQuery(sql, withArgumentsIn: feedIDs) {
	//				fetchedArticles = self.articlesWithResultSet(resultSet)
	//			}
	//		}
	//
	//		let articles = articleCache.uniquedArticles(fetchedArticles, statusesTable: statusesTable)
	//		return filteredArticles(articles, feedCounts: counts)
	//	}

	// MARK: Saving Articles
	
//	func saveUpdatedAndNewArticles(_ articleChanges: Set<NSDictionary>, newArticles: Set<Article>) {
//		
//		if articleChanges.isEmpty && newArticles.isEmpty {
//			return
//		}
//		
//		statusesTable.assertNoMissingStatuses(newArticles)
//		articleCache.cacheArticles(newArticles)
//		
//		let newArticleDictionaries = newArticles.map { (oneArticle) in
//			return oneArticle.databaseDictionary()
//		}
//		
//		queue.update { (database: FMDatabase!) -> Void in
//			
//			if !articleChanges.isEmpty {
//				
//				for oneDictionary in articleChanges {
//					
//					let oneArticleDictionary = oneDictionary.mutableCopy() as! NSMutableDictionary
//					let articleID = oneArticleDictionary[DatabaseKey.articleID]!
//					oneArticleDictionary.removeObject(forKey: DatabaseKey.articleID)
//					
//					let _ = database.rs_updateRows(with: oneArticleDictionary as [NSObject: AnyObject], whereKey: DatabaseKey.articleID, equalsValue: articleID, tableName: DatabaseTableName.articles)
//				}
//				
//			}
//			if !newArticleDictionaries.isEmpty {
//				
//				for oneNewArticleDictionary in newArticleDictionaries {
//					let _ = database.rs_insertRow(with: oneNewArticleDictionary as [NSObject: AnyObject], insertType: RSDatabaseInsertOrReplace, tableName: DatabaseTableName.articles)
//				}
//			}
//		}
//	}
//
//	// MARK: Updating Articles
//	
//	func updateArticles(_ articles: [String: Article], parsedArticles: [String: ParsedItem], feed: Feed, completionHandler: @escaping RSVoidCompletionBlock) {
//		
//		statusesTable.ensureStatusesForParsedArticles(Set(parsedArticles.values)) {
//			
//			let articleChanges = self.updateExistingArticles(articles, parsedArticles)
//			let newArticles = self.createNewArticles(articles, parsedArticles: parsedArticles, feedID: feed.feedID)
//			
//			self.saveUpdatedAndNewArticles(articleChanges, newArticles: newArticles)
//			
//			completionHandler()
//		}
//	}
//
//	func articlesDictionary(_ articles: NSSet) -> [String: AnyObject] {
//		
//		var d = [String: AnyObject]()
//		for oneArticle in articles {
//			let oneArticleID = (oneArticle as AnyObject).value(forKey: DatabaseKey.articleID) as! String
//			d[oneArticleID] = oneArticle as AnyObject
//		}
//		return d
//	}
//	
//	func updateExistingArticles(_ articles: [String: Article], _ parsedArticles: [String: ParsedItem]) -> Set<NSDictionary> {
//		
//		var articleChanges = Set<NSDictionary>()
//		
//		for oneArticle in articles.values {
//			if let oneParsedArticle = parsedArticles[oneArticle.articleID] {
//				if let oneArticleChanges = oneArticle.updateWithParsedArticle(oneParsedArticle) {
//					articleChanges.insert(oneArticleChanges)
//				}
//			}
//		}
//		
//		return articleChanges
//	}
//
//	// MARK: Creating Articles
//	
//	func createNewArticlesWithParsedArticles(_ parsedArticles: Set<ParsedItem>, feedID: String) -> Set<Article> {
//		
//		return Set(parsedArticles.map { Article(account: account, feedID: feedID, parsedArticle: $0) })
//	}
//	
//	func articlesWithParsedArticles(_ parsedArticles: Set<ParsedItem>, feedID: String) -> Set<Article> {
//		
//		var localArticles = Set<Article>()
//		
//		for oneParsedArticle in parsedArticles {
//			let oneLocalArticle = Article(account: self.account, feedID: feedID, parsedArticle: oneParsedArticle)
//			localArticles.insert(oneLocalArticle)
//		}
//		
//		return localArticles
//	}
//	
//	func createNewArticles(_ existingArticles: [String: Article], parsedArticles: [String: ParsedItem], feedID: String) -> Set<Article> {
//		
//		let newParsedArticles = parsedArticlesMinusExistingArticles(parsedArticles, existingArticles: existingArticles)
//		let newArticles = createNewArticlesWithParsedArticles(newParsedArticles, feedID: feedID)
//		
//		statusesTable.attachCachedUniqueStatuses(newArticles)
//		
//		return newArticles
//	}
//	
//	func parsedArticlesMinusExistingArticles(_ parsedArticles: [String: ParsedItem], existingArticles: [String: Article]) -> Set<ParsedItem> {
//		
//		var result = Set<ParsedItem>()
//		
//		for oneParsedArticle in parsedArticles.values {
//			
//			if let _ = existingArticles[oneParsedArticle.databaseID] {
//				continue
//			}
//			result.insert(oneParsedArticle)
//		}
//		
//		return result
//	}
//	
//	// MARK: Fetching Articles
//	
//	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject]?) -> Set<Article> {
//		
//		let sql = "select * from articles where \(whereClause);"
//		logSQL(sql)
//		
//		if let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) {
//			return articlesWithResultSet(resultSet, database)
//		}
//		
//		return Set<Article>()
//	}
//
//	func articlesWithResultSet(_ resultSet: FMResultSet, _ database: FMDatabase) -> Set<Article> {
//
//		let fetchedArticles = resultSet.mapToSet { Article(account: self.account, row: $0) }
//
//		statusesTable.attachStatuses(fetchedArticles, database)
//		authorsTable.attachAuthors(fetchedArticles, database)
//		tagsTable.attachTags(fetchedArticles, database)
//		attachmentsTable.attachAttachments(fetchedArticles, database)
//
//		return fetchedArticles
//	}
//
//	func fetchArticlesForFeedID(_ feedID: String, database: FMDatabase) -> Set<Article> {
//		
//		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [feedID as AnyObject])
//	}
//	
//	// MARK: Unread counts
//	
//	func numberOfArticles(_ feedID: String, _ database: FMDatabase) -> Int {
//		
//		let sql = "select count(*) from articles where feedID = ?;"
//		logSQL(sql)
//		
//		return numberWithSQLAndParameters(sql, parameters: [feedID], database)
//	}
//	
//	func unreadCount(_ feedID: String, _ database: FMDatabase) -> Int {
//		
//		let totalNumberOfArticles = numberOfArticles(feedID, database)
//		
//		if totalNumberOfArticles <= minimumNumberOfArticles {
//			return unreadCountIgnoringCutoffDate(feedID, database)
//		}
//		return unreadCountRespectingCutoffDate(feedID, database)
//	}
//	
//	func unreadCountIgnoringCutoffDate(_ feedID: String, _ database: FMDatabase) -> Int {
//		
//		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0;"
//		logSQL(sql)
//		
//		return numberWithSQLAndParameters(sql, parameters: [feedID], database)
//	}
//	
//	func unreadCountRespectingCutoffDate(_ feedID: String, _ database: FMDatabase) -> Int {
//		
//		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0 and (starred=1 or dateArrived>?);"
//		logSQL(sql)
//		
//		return numberWithSQLAndParameters(sql, parameters: [feedID, articleArrivalCutoffDate], database)
//	}
//	
//	// MARK: Filtering out old articles
//	
//	func articleIsOlderThanCutoffDate(_ article: Article) -> Bool {
//		
//		if let dateArrived = article.status?.dateArrived {
//			return dateArrived < articleArrivalCutoffDate
//		}
//		return false
//	}
//	
//	func articleShouldBeSavedForever(_ article: Article) -> Bool {
//		
//		return article.status.starred
//	}
//	
//	func articleShouldAppearToUser(_ article: Article, _ numberOfArticlesInFeed: Int) -> Bool {
//
//		if numberOfArticlesInFeed <= minimumNumberOfArticles {
//			return true
//		}
//		return articleShouldBeSavedForever(article) || !articleIsOlderThanCutoffDate(article)
//	}
//	
//	private static let minimumNumberOfArticlesInFeed = 10
//	
//	func filteredArticles(_ articles: Set<Article>, feedCounts: [String: Int]) -> Set<Article> {
//
//		var articlesSet = Set<Article>()
//
//		for oneArticle in articles {
//			if let feedCount = feedCounts[oneArticle.feedID], articleShouldAppearToUser(oneArticle, feedCount) {
//				articlesSet.insert(oneArticle)
//			}
//
//		}
//
//		return articlesSet
//	}
//	
//
//	func feedIDsFromArticles(_ articles: Set<Article>) -> Set<String> {
//		
//		return Set(articles.map { $0.feedID })
//	}
//	
//	func deletePossibleOldArticles(_ articles: Set<Article>) {
//		
//		let feedIDs = feedIDsFromArticles(articles)
//		if feedIDs.isEmpty {
//			return
//		}
//	}
}
