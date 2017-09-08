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
typealias UpdateArticlesWithFeedCompletionBlock = (Set<Article>, Set<Article>) -> Void

public final class Database {

	private let queue: RSDatabaseQueue
	private let databaseFile: String
	private let articlesTable: ArticlesTable
	private var articleArrivalCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 3 * 31)!
	private let minimumNumberOfArticles = 10

	public init(databaseFile: String) {

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
	}

	public func fetchArticlesAsync(for feed: Feed, _ resultBlock: @escaping ArticleResultBlock) {

		articlesTable.fetchArticlesAsync(feed, withLimits: true, resultBlock)
	}

	public func fetchUnreadArticles(for folder: Folder) -> Set<Article> {
		
		return articlesTable.fetchUnreadArticles(for: folder.flattenedFeeds())
	}

	// MARK: - Unread Counts
	
	public func fetchUnreadCounts(for feeds: Set<Feed>, _ completion: @escaping UnreadCountCompletionBlock) {
		
		articlesTable.fetchUnreadCounts(feeds, completion)
	}

	// MARK: - Updating Articles

	public func update(feed: Feed, parsedFeed: ParsedFeed, completion: @escaping RSVoidCompletionBlock) {

		return articlesTable.update(feed, parsedFeed, completion)
	}
	
	// MARK: - Status
	
	public func mark(_ articles: Set<Article>, statusKey: String, flag: Bool) {

		articlesTable.mark(articles, statusKey, flag)
	}
}

// MARK: - Private

private extension Database {
	
	


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
//	func articleShouldAppearToUser(_ article: Article, _ numberOfArticlesInFeed: Int) -> Bool {
//
//		if numberOfArticlesInFeed <= minimumNumberOfArticles {
//			return true
//		}
//		return articleShouldBeSavedForever(article) || !articleIsOlderThanCutoffDate(article)
//	}
//	
//	
//	func deletePossibleOldArticles(_ articles: Set<Article>) {
//		
//		let feedIDs = feedIDsFromArticles(articles)
//		if feedIDs.isEmpty {
//			return
//		}
//	}
}
