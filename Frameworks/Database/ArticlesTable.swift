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
	private weak var account: Account?
	private let queue: RSDatabaseQueue
	private let statusesTable = StatusesTable()
	private let authorsLookupTable: DatabaseLookupTable
	private let attachmentsLookupTable: DatabaseLookupTable
	private let tagsLookupTable: DatabaseLookupTable
	private let articleCache = ArticleCache()
	
	// TODO: update articleCutoffDate as time passes and based on user preferences.
	private var articleCutoffDate = NSDate.rs_dateWithNumberOfDays(inThePast: 3 * 31)!

	init(name: String, account: Account, queue: RSDatabaseQueue) {

		self.name = name
		self.account = account
		self.queue = queue

		let authorsTable = AuthorsTable(name: DatabaseTableName.authors)
		self.authorsLookupTable = DatabaseLookupTable(name: DatabaseTableName.authorsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.authorID, relatedTable: authorsTable, relationshipName: RelationshipName.authors)
		
		let tagsTable = TagsTable(name: DatabaseTableName.tags)
		self.tagsLookupTable = DatabaseLookupTable(name: DatabaseTableName.tags, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.tagName, relatedTable: tagsTable, relationshipName: RelationshipName.tags)
		
		let attachmentsTable = AttachmentsTable(name: DatabaseTableName.attachments)
		self.attachmentsLookupTable = DatabaseLookupTable(name: DatabaseTableName.attachmentsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.attachmentID, relatedTable: attachmentsTable, relationshipName: RelationshipName.attachments)
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

		if parsedFeed.items.isEmpty {

			// Once upon a time in an early version of NetNewsWire there was a bug with this issue.
			// The design, at the time, was that NetNewsWire would always show only what’s currently in a feed —
			// no more and no less.
			// This meant that if a feed had zero items, then all the articles for that feed would be deleted.
			// There were two problems with that:
			// 1. People didn’t expect articles to just disappear like that.
			// 2. Technorati (R.I.P.) had a bug where some of its feeds, at seemingly random times, would have zero items.
			// So this hit people. THEY WERE NOT HAPPY.
			// These days we just ignore empty feeds. Who cares if they’re empty. It just means less work the app has to do.

			completion()
			return
		}

		fetchArticlesAsync(feed) { (articles) in
			self.updateArticles(articles.dictionary(), parsedFeed.itemsDictionary(with: feed), feed, completion)
		}
	}

	// MARK: Unread Counts
	
	func fetchUnreadCounts(_ feeds: Set<Feed>, _ completion: @escaping UnreadCountCompletionBlock) {
		
		let feedIDs = feeds.feedIDs()
		var unreadCountTable = UnreadCountTable()

		queue.fetch { (database) in

			for feedID in feedIDs {
				unreadCountTable[feedID] = self.fetchUnreadCount(feedID, database)
			}

			DispatchQueue.main.async() {
				completion(unreadCountTable)
			}
		}
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
}

// MARK: - Private

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

		// Don’t fetch articles that shouldn’t appear in the UI. The rules:
		// * Must not be deleted.
		// * Must be either 1) starred or 2) dateArrived must be newer than cutoff date.

		let sql = "select * from articles natural join statuses where \(whereClause) and userDeleted=0 and (starred=1 or dateArrived>?);"
		return articlesWithSQL(sql, parameters + [articleCutoffDate as AnyObject], database)
	}

	func fetchUnreadCount(_ feedID: String, _ database: FMDatabase) -> Int {
		
		// Count only the articles that would appear in the UI.
		// * Must be unread.
		// * Must not be deleted.
		// * Must be either 1) starred or 2) dateArrived must be newer than cutoff date.

		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0 and userDeleted=0 and (starred=1 or dateArrived>?);"
		return numberWithSQLAndParameters(sql, [feedID, articleCutoffDate], in: database)
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

	// MARK: Saving/Updating

	func updateArticles(_ articlesDictionary: [String: Article], _ parsedItemsDictionary: [String: ParsedItem], _ feed: Feed, _ completion: @escaping RSVoidCompletionBlock) {

		
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




