//
//  ArticlesTable.swift
//  Evergreen
//
//  Created by Brent Simmons on 5/9/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSParser
import Data

final class ArticlesTable: DatabaseTable {

	let name: String
	let databaseIDKey = DatabaseKey.articleID
	private weak var account: Account?
	private let queue: RSDatabaseQueue
	private let statusesTable: StatusesTable
	private let authorsLookupTable: DatabaseLookupTable
	private let attachmentsLookupTable: DatabaseLookupTable
	private let tagsLookupTable: DatabaseLookupTable
	private let articleCache = ArticleCache()
	
	init(name: String, account: Account, queue: RSDatabaseQueue) {

		self.name = name
		self.account = account
		self.queue = queue

		self.statusesTable = StatusesTable(name: DatabaseTableName.statuses)
		let authorsTable = AuthorsTable(name: DatabaseTableName.authors)
		self.authorsLookupTable = DatabaseLookupTable(name: DatabaseTableName.authorsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.authorID, relatedTable: authorsTable, relationshipName: RelationshipName.authors)
		
		let tagsTable = TagsTable(name: DatabaseTableName.tags)
		self.tagsLookupTable = DatabaseLookupTable(name: DatabaseTableName.tags, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.tagName, relatedTable: tagsTable, relationshipName: RelationshipName.tags)
		
		let attachmentsTable = AttachmentsTable(name: DatabaseTableName.attachments)
		self.attachmentsLookupTable = DatabaseLookupTable(name: DatabaseTableName.attachmentsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.attachmentID, relatedTable: attachmentsTable, relationshipName: RelationshipName.attachments)
	}

	// MARK: DatabaseTable Methods
	
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {

		if let article = articleWithRow(row) {
			return article as DatabaseObject
		}
		return nil
	}

	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		
		// TODO
	}

	// MARK: Fetching
	
	func fetchArticles(_ feed: Feed) -> Set<Article> {
		
		let feedID = feed.feedID
		var articles = Set<Article>()

		queue.fetchSync { (database: FMDatabase!) -> Void in
			articles = self.fetchArticlesForFeedID(feedID, database: database)
		}

		return articleCache.uniquedArticles(articles)
	}

	func fetchArticlesAsync(_ feed: Feed, _ resultBlock: @escaping ArticleResultBlock) {

		let feedID = feed.feedID

		queue.fetch { (database: FMDatabase!) -> Void in

			let fetchedArticles = self.fetchArticlesForFeedID(feedID, database: database)

			DispatchQueue.main.async {
				let articles = self.articleCache.uniquedArticles(fetchedArticles)
				resultBlock(articles)
			}
		}
	}
	
	func fetchUnreadArticles(for feeds: Set<Feed>) -> Set<Article> {

		return fetchUnreadArticles(feeds.feedIDs())
	}
	
	// MARK: Updating
	
	func update(_ feed: Feed, _ parsedFeed: ParsedFeed, _ completion: @escaping RSVoidCompletionBlock) {
		
		// TODO
	}
	
	// MARK: Unread Counts
	
	func fetchUnreadCounts(_ feeds: Set<Feed>, _ completion: @escaping UnreadCountCompletionBlock) {
		
		// TODO
	}
	
	// MARK: Status
	
	func mark(_ articles: Set<Article>, _ statusKey: String, _ flag: Bool) {
		
		// Sets flag in both memory and in database.
		
		let articleIDs = articles.flatMap { (article) -> String? in
			
			guard let status = article.status else {
				assertionFailure("Each article must have a status.")
				return nil
			}
			
			if status.boolStatus(forKey: statusKey) == flag {
				return nil
			}
			status.setBoolStatus(flag, forKey: statusKey)
			return article.articleID
		}
		
		if articleIDs.isEmpty {
			return
		}
		
		queue.update { (database) in
			self.statusesTable.markArticleIDs(Set(articleIDs), statusKey, flag, database)
		}
	}
	
	
//	typealias FeedCountCallback = (Int) -> Void
//
//	func numberOfArticlesWithFeedID(_ feedID: String, callback: @escaping FeedCountCallback) {
//
//		queue.fetch { (database: FMDatabase!)
//
//			let sql = "select count(*) from articles where feedID = ?;"
//			var numberOfArticles = -1
//
//			if let resultSet = database.executeQuery(sql, withArgumentsIn: [feedID]) {
//
//				while (resultSet.next()) {
//					numberOfArticles = resultSet.long(forColumnIndex: 0)
//					break
//				}
//			}
//
//			DispatchQueue.main.async() {
//				callback(numberOfArticles)
//			}
//		}
//
//	}
}

// MARK: -

private extension ArticlesTable {

	// MARK: Fetching

	func attachRelatedObjects(_ articles: Set<Article>, _ database: FMDatabase) {

		let articleArray = articles.map { $0 as DatabaseObject }
		
		authorsLookupTable.attachRelatedObjects(to: articleArray, in: database)
		attachmentsLookupTable.attachRelatedObjects(to: articleArray, in: database)
		tagsLookupTable.attachRelatedObjects(to: articleArray, in: database)

		// In theory, it’s impossible to have a fetched article without a status.
		// Let’s handle that impossibility anyway.
		// Remember that, if nothing else, the user can edit the SQLite database,
		// and thus could delete all their statuses.

		statusesTable.ensureStatusesForArticles(articles, database)
	}

	func articleWithRow(_ row: FMResultSet) -> Article? {

		guard let account = account else {
			return nil
		}
		guard let article = Article(row: row, account: account) else {
			return nil
		}

		// Note: the row is a result of a JOIN query with the statuses table,
		// so we can get the status at the same time and avoid additional database lookups.

		article.status = statusesTable.statusWithRow(row)
		return article
	}

	func articlesWithResultSet(_ resultSet: FMResultSet, _ database: FMDatabase) -> Set<Article> {

		let articles = resultSet.mapToSet(articleWithRow)
		attachRelatedObjects(articles, database)
		return articles
	}

	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject]) -> Set<Article> {

		let sql = "select * from articles natural join statuses where \(whereClause);"
		return articlesWithSQL(sql, parameters, database)
	}

	func fetchArticlesForFeedID(_ feedID: String, database: FMDatabase) -> Set<Article> {

		return fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [feedID as AnyObject])
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
			articles = self.fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
		}

		return articleCache.uniquedArticles(articles)
	}

	func articlesWithSQL(_ sql: String, _ parameters: [AnyObject], _ database: FMDatabase) -> Set<Article> {

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return Set<Article>()
		}
		return articlesWithResultSet(resultSet, database)
	}
}

// MARK: -

private struct ArticleCache {
	
	// Main thread only — unlike the other object caches.
	// The cache contains a given article only until all outside references are gone.
	// Cache key is articleID.
	
	private let articlesMapTable: NSMapTable<NSString, Article> = NSMapTable.weakToWeakObjects()

	func uniquedArticles(_ articles: Set<Article>) -> Set<Article> {

		var articlesToReturn = Set<Article>()

		for article in articles {
			let articleID = article.articleID
			if let cachedArticle = cachedArticle(for: articleID) {
				articlesToReturn.insert(cachedArticle)
			}
			else {
				articlesToReturn.insert(article)
				addToCache(article)
			}
		}

		// At this point, every Article must have an attached Status.
		assert(articlesToReturn.eachHasAStatus())

		return articlesToReturn
	}
	
	private func cachedArticle(for articleID: String) -> Article? {
	
		return articlesMapTable.object(forKey: articleID as NSString)
	}
	
	private func addToCache(_ article: Article) {
	
		articlesMapTable.setObject(article, forKey: article.articleID as NSString)
	}
}

