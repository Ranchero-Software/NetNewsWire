//
//  LocalDatabase.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSXML
import RSDatabase
import DataModel

let sqlLogging = false

func logSQL(_ sql: String) {
	if sqlLogging {
		print("SQL: \(sql)")
	}
}

typealias LocalArticleResultBlock = (Set<LocalArticle>) -> Void

private let articlesTableName = "articles"

final class LocalDatabase {

	fileprivate let queue: RSDatabaseQueue
	private let databaseFile: String
	fileprivate let statusesManager: LocalStatusesManager
	fileprivate let articleCache: LocalArticleCache
	fileprivate var articleArrivalCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 3 * 31)!
	fileprivate let minimumNumberOfArticles = 10
	
	var account: LocalAccount!

	init(databaseFile: String) {

		self.databaseFile = databaseFile
		self.queue = RSDatabaseQueue(filepath: databaseFile, excludeFromBackup: false)
		self.statusesManager = LocalStatusesManager(queue: self.queue)
		self.articleCache = LocalArticleCache(statusesManager: self.statusesManager)
		
		let createStatementsPath = Bundle(for: type(of: self)).path(forResource: "LocalCreateStatements", ofType: "sql")!
		let createStatements = try! NSString(contentsOfFile: createStatementsPath, encoding: String.Encoding.utf8.rawValue)
		queue.createTables(usingStatements: createStatements as String)
		queue.vacuumIfNeeded()
	}

	// MARK: API

	func startup() {

		assert(account != nil)
//		deleteOldArticles(articleIDsInFeeds)
	}

	// MARK: Fetching Articles

	func fetchArticlesForFeed(_ feed: LocalFeed) -> Set<LocalArticle> {

//		if let articles = articleCache.cachedArticlesForFeedID(feed.feedID) {
//			return articles
//		}

		var fetchedArticles = Set<LocalArticle>()
		let feedID = feed.feedID

		queue.fetchSync { (database: FMDatabase!) -> Void in

			fetchedArticles = self.fetchArticlesForFeedID(feedID, database: database)
		}

		let articles = articleCache.uniquedArticles(fetchedArticles)
		return filteredArticles(articles, feedCounts: [feed.feedID: fetchedArticles.count])
	}

	func fetchArticlesForFeedAsync(_ feed: LocalFeed, _ resultBlock: @escaping LocalArticleResultBlock) {

//		if let articles = articleCache.cachedArticlesForFeedID(feed.feedID) {
//			resultBlock(articles)
//			return
//		}

		let feedID = feed.feedID

		queue.fetch { (database: FMDatabase!) -> Void in

			let fetchedArticles = self.fetchArticlesForFeedID(feedID, database: database)

			DispatchQueue.main.async() { () -> Void in

				let articles = self.articleCache.uniquedArticles(fetchedArticles)
				let filteredArticles = self.filteredArticles(articles, feedCounts: [feed.feedID: fetchedArticles.count])
				resultBlock(filteredArticles)
			}
		}
	}

	func feedIDCountDictionariesWithResultSet(_ resultSet: FMResultSet) -> [String: Int] {

		var counts = [String: Int]()

		while (resultSet.next()) {

			if let oneFeedID = resultSet.string(forColumnIndex: 0) {
				let count = resultSet.int(forColumnIndex: 1)
				counts[oneFeedID] = Int(count)
			}
		}

		return counts
	}

	func countsForAllFeeds(_ database: FMDatabase) -> [String: Int] {
		
		let sql = "select distinct feedID, count(*) as count from articles group by feedID;"

		if let resultSet = database.executeQuery(sql, withArgumentsIn: []) {
			return feedIDCountDictionariesWithResultSet(resultSet)
		}
		
		return [String: Int]()
	}

	func countsForFeedIDs(_ feedIDs: [String], _ database: FMDatabase) -> [String: Int] {

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select distinct feedID, count(*) from articles where feedID in \(placeholders) group by feedID;"
		logSQL(sql)

		if let resultSet = database.executeQuery(sql, withArgumentsIn: feedIDs) {
			return feedIDCountDictionariesWithResultSet(resultSet)
		}

		return [String: Int]()

	}

	func fetchUnreadArticlesForFolder(_ folder: LocalFolder) -> Set<LocalArticle> {
		
		return fetchUnreadArticlesForFeedIDs(Array(folder.flattenedFeedIDs))
	}
	
	func fetchUnreadArticlesForFeedIDs(_ feedIDs: [String]) -> Set<LocalArticle> {
		
		if feedIDs.isEmpty {
			return Set<LocalArticle>()
		}
		
		var fetchedArticles = Set<LocalArticle>()
		var counts = [String: Int]()
		
		queue.fetchSync { (database: FMDatabase!) -> Void in
			
			counts = self.countsForFeedIDs(feedIDs, database)
			
			// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read = 0
			
			let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
			let sql = "select * from articles natural join statuses where feedID in \(placeholders) and read=0;"
			logSQL(sql)
			
			if let resultSet = database.executeQuery(sql, withArgumentsIn: feedIDs) {
				fetchedArticles = self.articlesWithResultSet(resultSet)
			}
		}
		
		let articles = articleCache.uniquedArticles(fetchedArticles)
		return filteredArticles(articles, feedCounts: counts)
	}
	
	typealias UnreadCountCompletionBlock = ([String: Int]) -> Void //feedID: unreadCount
	
	func updateUnreadCounts(for feedIDs: Set<String>, completion: @escaping UnreadCountCompletionBlock) {
		
		queue.fetch { (database: FMDatabase!) -> Void in
			
			var unreadCounts = [String: Int]()
			for oneFeedID in feedIDs {
				unreadCounts[oneFeedID] = self.unreadCount(oneFeedID, database)
			}
			
			DispatchQueue.main.async() { () -> Void in
				completion(unreadCounts)
			}
		}
	}
	

	// MARK: Updating Articles

	func updateFeedWithParsedFeed(_ feed: LocalFeed, parsedFeed: RSParsedFeed, completionHandler: @escaping RSVoidCompletionBlock) {

		if parsedFeed.articles.isEmpty {
			completionHandler()
			return
		}

		let parsedArticlesDictionary = self.articlesDictionary(parsedFeed.articles as NSSet) as! [String: RSParsedArticle]

		fetchArticlesForFeedAsync(feed) { (articles) -> Void in

			let articlesDictionary = self.articlesDictionary(articles as NSSet) as! [String: LocalArticle]
			self.updateArticles(articlesDictionary, parsedArticles: parsedArticlesDictionary, feed: feed, completionHandler: completionHandler)
		}
	}
	
	// MARK: Status
	
	func markArticles(_ articles: NSSet, statusKey: ArticleStatusKey, flag: Bool) {
		
		statusesManager.markArticles(articles as! Set<LocalArticle>, statusKey: statusKey, flag: flag)
	}
}

// MARK: Private

private extension LocalDatabase {
	
	// MARK: Saving Articles
	
	func saveUpdatedAndNewArticles(_ articleChanges: Set<NSDictionary>, newArticles: Set<LocalArticle>) {
		
		if articleChanges.isEmpty && newArticles.isEmpty {
			return
		}
		
		statusesManager.assertNoMissingStatuses(newArticles)
		articleCache.cacheArticles(newArticles)
		
		let newArticleDictionaries = newArticles.map { (oneArticle) in
			return oneArticle.databaseDictionary
		}
		
		queue.update { (database: FMDatabase!) -> Void in
			
			if !articleChanges.isEmpty {
				
				for oneDictionary in articleChanges {
					
					let oneArticleDictionary = oneDictionary.mutableCopy() as! NSMutableDictionary
					let articleID = oneArticleDictionary[articleIDKey]!
					oneArticleDictionary.removeObject(forKey: articleIDKey)
					
					let _ = database.rs_updateRows(with: oneArticleDictionary as [NSObject: AnyObject], whereKey: articleIDKey, equalsValue: articleID, tableName: articlesTableName)
				}
				
			}
			if !newArticleDictionaries.isEmpty {
				
				for oneNewArticleDictionary in newArticleDictionaries {
					let _ = database.rs_insertRow(with: oneNewArticleDictionary as [NSObject: AnyObject], insertType: RSDatabaseInsertOrReplace, tableName: articlesTableName)
				}
			}
		}
	}

	// MARK: Updating Articles
	
	func updateArticles(_ articles: [String: LocalArticle], parsedArticles: [String: RSParsedArticle], feed: LocalFeed, completionHandler: @escaping RSVoidCompletionBlock) {
		
		statusesManager.ensureStatusesForParsedArticles(Set(parsedArticles.values)) {
			
			let articleChanges = self.updateExistingArticles(articles, parsedArticles)
			let newArticles = self.createNewArticles(articles, parsedArticles: parsedArticles, feedID: feed.feedID)
			
			self.saveUpdatedAndNewArticles(articleChanges, newArticles: newArticles)
			
			completionHandler()
		}
	}

	func articlesDictionary(_ articles: NSSet) -> [String: AnyObject] {
		
		var d = [String: AnyObject]()
		for oneArticle in articles {
			let oneArticleID = (oneArticle as AnyObject).value(forKey: articleIDKey) as! String
			d[oneArticleID] = oneArticle as AnyObject
		}
		return d
	}
	
	func updateExistingArticles(_ articles: [String: LocalArticle], _ parsedArticles: [String: RSParsedArticle]) -> Set<NSDictionary> {
		
		var articleChanges = Set<NSDictionary>()
		
		for oneArticle in articles.values {
			if let oneParsedArticle = parsedArticles[oneArticle.articleID] {
				if let oneArticleChanges = oneArticle.updateWithParsedArticle(oneParsedArticle) {
					articleChanges.insert(oneArticleChanges)
				}
			}
		}
		
		return articleChanges
	}

	// MARK: Creating Articles
	
	func createNewArticlesWithParsedArticles(_ parsedArticles: Set<RSParsedArticle>, feedID: String) -> Set<LocalArticle> {
		
		return Set(parsedArticles.map { LocalArticle(account: account, feedID: feedID, parsedArticle: $0) })
	}
	
	func articlesWithParsedArticles(_ parsedArticles: Set<RSParsedArticle>, feedID: String) -> Set<LocalArticle> {
		
		var localArticles = Set<LocalArticle>()
		
		for oneParsedArticle in parsedArticles {
			let oneLocalArticle = LocalArticle(account: self.account, feedID: feedID, parsedArticle: oneParsedArticle)
			localArticles.insert(oneLocalArticle)
		}
		
		return localArticles
	}
	
	func createNewArticles(_ existingArticles: [String: LocalArticle], parsedArticles: [String: RSParsedArticle], feedID: String) -> Set<LocalArticle> {
		
		let newParsedArticles = parsedArticlesMinusExistingArticles(parsedArticles, existingArticles: existingArticles)
		let newArticles = createNewArticlesWithParsedArticles(newParsedArticles, feedID: feedID)
		
		statusesManager.attachCachedUniqueStatuses(newArticles)
		
		return newArticles
	}
	
	func parsedArticlesMinusExistingArticles(_ parsedArticles: [String: RSParsedArticle], existingArticles: [String: LocalArticle]) -> Set<RSParsedArticle> {
		
		var result = Set<RSParsedArticle>()
		
		for oneParsedArticle in parsedArticles.values {
			
			if let _ = existingArticles[oneParsedArticle.articleID] {
				continue
			}
			result.insert(oneParsedArticle)
		}
		
		return result
	}
	
	// MARK: Fetching Articles
	
	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject]?) -> Set<LocalArticle> {
		
		let sql = "select * from articles natural join statuses where \(whereClause);"
		logSQL(sql)
		
		if let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) {
			return articlesWithResultSet(resultSet)
		}
		
		return Set<LocalArticle>()
	}

	func articlesWithResultSet(_ resultSet: FMResultSet) -> Set<LocalArticle> {

		var fetchedArticles = Set<LocalArticle>()

		while (resultSet.next()) {

			if let oneArticle = LocalArticle(account: self.account, row: resultSet) {
				oneArticle.status = LocalArticleStatus(row: resultSet)
				fetchedArticles.insert(oneArticle)
			}
		}

		return fetchedArticles
	}

	func fetchArticlesForFeedID(_ feedID: String, database: FMDatabase) -> Set<LocalArticle> {
		
		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [feedID as AnyObject])
	}
	
	// MARK: Unread counts
	
	func numberWithCountResultSet(_ resultSet: FMResultSet?) -> Int {
		
		guard let resultSet = resultSet else {
			return 0
		}
		if resultSet.next() {
			return Int(resultSet.int(forColumnIndex: 0))
		}
		return 0
	}
	
	func numberWithSQLAndParameters(_ sql: String, parameters: [Any], _ database: FMDatabase) -> Int {
		
		let resultSet = database.executeQuery(sql, withArgumentsIn: parameters)
		return numberWithCountResultSet(resultSet)
	}
	
	func numberOfArticles(_ feedID: String, _ database: FMDatabase) -> Int {
		
		let sql = "select count(*) from articles where feedID = ?;"
		logSQL(sql)
		
		return numberWithSQLAndParameters(sql, parameters: [feedID], database)
	}
	
	func unreadCount(_ feedID: String, _ database: FMDatabase) -> Int {
		
		let totalNumberOfArticles = numberOfArticles(feedID, database)
		
		if totalNumberOfArticles <= minimumNumberOfArticles {
			return unreadCountIgnoringCutoffDate(feedID, database)
		}
		return unreadCountRespectingCutoffDate(feedID, database)
	}
	
	func unreadCountIgnoringCutoffDate(_ feedID: String, _ database: FMDatabase) -> Int {
		
		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0;"
		logSQL(sql)
		
		return numberWithSQLAndParameters(sql, parameters: [feedID], database)
	}
	
	func unreadCountRespectingCutoffDate(_ feedID: String, _ database: FMDatabase) -> Int {
		
		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0 and (starred=1 or dateArrived>?);"
		logSQL(sql)
		
		return numberWithSQLAndParameters(sql, parameters: [feedID, articleArrivalCutoffDate], database)
	}
	
	// MARK: Filtering out old articles
	
	func articleIsOlderThanCutoffDate(_ article: LocalArticle) -> Bool {
		
		if let dateArrived = article.status?.dateArrived {
			return dateArrived < articleArrivalCutoffDate
		}
		return false
	}
	
	func articleShouldBeSavedForever(_ article: LocalArticle) -> Bool {
		
		return article.status.starred
	}
	
	func articleShouldAppearToUser(_ article: LocalArticle, _ numberOfArticlesInFeed: Int) -> Bool {

		if numberOfArticlesInFeed <= minimumNumberOfArticles {
			return true
		}
		return articleShouldBeSavedForever(article) || !articleIsOlderThanCutoffDate(article)
	}
	
	private static let minimumNumberOfArticlesInFeed = 10
	
	func filteredArticles(_ articles: Set<LocalArticle>, feedCounts: [String: Int]) -> Set<LocalArticle> {

		var articlesSet = Set<LocalArticle>()

		for oneArticle in articles {
			if let feedCount = feedCounts[oneArticle.feedID], articleShouldAppearToUser(oneArticle, feedCount) {
				articlesSet.insert(oneArticle)
			}

		}

		return articlesSet
	}
	
	typealias FeedCountCallback = (Int) -> Void
	
	func feedIDsFromArticles(_ articles: Set<LocalArticle>) -> Set<String> {
		
		return Set(articles.map { $0.feedID })
	}
	
	func deletePossibleOldArticles(_ articles: Set<LocalArticle>) {
		
		let feedIDs = feedIDsFromArticles(articles)
		if feedIDs.isEmpty {
			return
		}
	}
	
	func numberOfArticlesInFeedID(_ feedID: String, callback: @escaping FeedCountCallback) {

		queue.fetch { (database: FMDatabase!) -> Void in
			
			let sql = "select count(*) from articles where feedID = ?;"
			logSQL(sql)
			
			var numberOfArticles = -1
			
			if let resultSet = database.executeQuery(sql, withArgumentsIn: [feedID]) {
				
				while (resultSet.next()) {
					
					numberOfArticles = resultSet.long(forColumnIndex: 0)
					break
				}
			}

			DispatchQueue.main.async() {
				callback(numberOfArticles)
			}
		}
	}
	
	func deleteOldArticlesInFeed(_ feed: LocalFeed) {
		
		numberOfArticlesInFeedID(feed.feedID) { (numberOfArticlesInFeed) in
			
			if numberOfArticlesInFeed <= LocalDatabase.minimumNumberOfArticlesInFeed {
				return
			}
			
			
			
			
		}
		
	}
	
	// MARK: Deleting Articles
	
//	func deleteOldArticles(_ articleIDsInFeeds: Set<String>) {
//		
//		queue.update { (database: FMDatabase!) -> Void in
//			
////			let cutoffDate = NSDate.rs_dateWithNumberOfDaysInThePast(60)
////			let articles = self.fetchArticlesWithWhereClause(database, whereClause: "statuses.dateArrived < ? limit 200", parameters: [cutoffDate])
//			
////			var articleIDsToDelete = Set<String>()
////			
////			for oneArticle in articles {
//				// TODO
////				if !localAccountShouldIncludeArticle(oneArticle, articleIDsInFeed: articleIDsInFeeds) {
////					articleIDsToDelete.insert(oneArticle.articleID)
////				}
////			}
//			
////			if !articleIDsToDelete.isEmpty {
////				database.rs_deleteRowsWhereKey(articleIDKey, inValues: Array(articleIDsToDelete), tableName: articlesTableName)
////			}
//		}
//	}

	
	
}
