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
	private let statusesTable: StatusesTable
	private let authorsLookupTable: DatabaseLookupTable
	private let attachmentsLookupTable: DatabaseLookupTable
	private let tagsLookupTable: DatabaseLookupTable

//	private let cachedArticles: NSMapTable<NSString, Article> = NSMapTable.weakToWeakObjects()

	init(name: String) {

		self.name = name
		
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
		
//		if let article = articleWithRow(row) {
//			
//		}
		return nil // TODO
	}

	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		
		// TODO
	}

	// MARK: Fetching
	
	func fetchArticles(_ feed: Feed) -> Set<Article> {
		
		return Set<Article>() // TODO
	}

	func fetchArticlesAsync(_ feed: Feed, _ resultBlock: @escaping ArticleResultBlock) {

		// TODO
	}
	
	func fetchUnreadArticles(_ feeds: Set<Feed>) -> Set<Article> {
	
		return Set<Article>() // TODO
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
		
		// TODO
	}
	
	
//	func uniquedArticles(_ fetchedArticles: Set<Article>, statusesTable: StatusesTable) -> Set<Article> {
//
//		var articles = Set<Article>()
//
//		for oneArticle in fetchedArticles {
//
//			assert(oneArticle.status != nil)
//
//			if let existingArticle = cachedArticle(oneArticle.databaseID) {
//				articles.insert(existingArticle)
//			}
//			else {
//				cacheArticle(oneArticle)
//				articles.insert(oneArticle)
//			}
//		}
//
//		statusesTable.attachCachedStatuses(articles)
//
//		return articles
//	}

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

//private extension ArticlesTable {

//	func cachedArticle(_ articleID: String) -> Article? {
//
//		return cachedArticles.object(forKey: articleID as NSString)
//	}
//
//	func cacheArticle(_ article: Article) {
//
//		cachedArticles.setObject(article, forKey: article.databaseID as NSString)
//	}
//
//	func cacheArticles(_ articles: Set<Article>) {
//
//		articles.forEach { cacheArticle($0) }
//	}
//}

