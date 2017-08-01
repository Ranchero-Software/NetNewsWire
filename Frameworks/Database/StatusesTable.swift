//
//  StatusesTable.swift
//  Evergreen
//
//  Created by Brent Simmons on 5/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSParser
import Data

final class StatusesTable: DatabaseTable {

	let name: String
	let queue: RSDatabaseQueue
	private let cache = ObjectCache<ArticleStatus>(keyPathForID: \ArticleStatus.articleID)

	init(name: String, queue: RSDatabaseQueue) {

		self.name = name
		self.queue = queue
	}

	func markArticles(_ articles: Set<Article>, statusKey: String, flag: Bool) {
		
		assertNoMissingStatuses(articles)
		let statuses = Set(articles.flatMap { $0.status })
		markArticleStatuses(statuses, statusKey: statusKey, flag: flag)
	}

	func attachCachedStatuses(_ articles: Set<Article>) {
		
		articles.forEach { (oneArticle) in
			
			if let cachedStatus = cache[oneArticle.databaseID] {
				oneArticle.status = cachedStatus
			}
			else if let oneArticleStatus = oneArticle.status {
				cache.add(oneArticleStatus)
			}
		}
	}
	
	func ensureStatusesForParsedArticles(_ parsedArticles: [ParsedItem], _ callback: @escaping RSVoidCompletionBlock) {

		// 1. Check cache for statuses
		// 2. Fetch statuses not found in cache
		// 3. Create, save, and cache statuses not found in database

		var articleIDs = Set(parsedArticles.map { $0.articleID })
		articleIDs = articleIDsMissingStatuses(articleIDs)
		if articleIDs.isEmpty {
			callback()
			return
		}
		
		queue.fetch { (database: FMDatabase!) -> Void in
			
			let statuses = self.fetchStatusesForArticleIDs(articleIDs, database: database)
			
			DispatchQueue.main.async {

				self.cache.addObjectsNotCached(Array(statuses))

				let newArticleIDs = self.articleIDsMissingStatuses(articleIDs)
				if !newArticleIDs.isEmpty {
					self.createAndSaveStatusesForArticleIDs(newArticleIDs)
				}

				callback()
			}
		}
	}
}

private extension StatusesTable {
	
	func assertNoMissingStatuses(_ articles: Set<Article>) {

		for oneArticle in articles {
			if oneArticle.status == nil {
				assertionFailure("All articles must have a status at this point.")
				return
			}
		}
	}

	// MARK: Fetching
	
	func fetchStatusesForArticleIDs(_ articleIDs: Set<String>, database: FMDatabase) -> Set<ArticleStatus> {
		
		if !articleIDs.isEmpty, let resultSet = selectRowsWhere(key: DatabaseKey.articleID, inValues: Array(articleIDs), in: database) {
			return articleStatusesWithResultSet(resultSet)
		}
		
		return Set<ArticleStatus>()
	}

	func articleStatusesWithResultSet(_ resultSet: FMResultSet) -> Set<ArticleStatus> {
		
		var statuses = Set<ArticleStatus>()
		
		while(resultSet.next()) {
			if let oneArticleStatus = ArticleStatus(row: resultSet) {
				statuses.insert(oneArticleStatus)
			}
		}
		
		return statuses
	}
	
	// MARK: Updating
	
	func markArticleStatuses(_ statuses: Set<ArticleStatus>, statusKey: String, flag: Bool) {

		// Ignore the statuses where status.[statusKey] == flag. Update the remainder and save in database.

		var articleIDsToUpdate = Set<String>()

		statuses.forEach { (oneStatus) in

			if oneStatus.boolStatus(forKey: statusKey) == flag {
				return
			}

			oneStatus.setBoolStatus(flag, forKey: statusKey)
			articleIDsToUpdate.insert(oneStatus.articleID)
		}

		if !articleIDsToUpdate.isEmpty {
			updateArticleStatusesInDatabase(articleIDsToUpdate, statusKey: statusKey, flag: flag)
		}
	}

	private func updateArticleStatusesInDatabase(_ articleIDs: Set<String>, statusKey: String, flag: Bool) {

		updateRowsWithValue(NSNumber(value: flag), valueKey: statusKey, whereKey: DatabaseKey.articleID, matches: Array(articleIDs))
	}
	
	// MARK: Creating

	func saveStatuses(_ statuses: Set<ArticleStatus>) {

		let statusArray = statuses.map { $0.databaseDictionary() }
		insertRows(statusArray, insertType: .orIgnore)
	}

	func createAndSaveStatusesForArticleIDs(_ articleIDs: Set<String>) {

		let now = Date()
		let statuses = articleIDs.map { ArticleStatus(articleID: $0, dateArrived: now) }
		cache.addObjectsNotCached(statuses)

		saveStatuses(Set(statuses))
	}

	// MARK: Utilities
	
	func articleIDsMissingStatuses(_ articleIDs: Set<String>) -> Set<String> {
		
		return Set(articleIDs.filter { !objectWithIDIsCached[$0] })
	}
}

extension ParsedItem {

	var articleID: String {
		get {
			return "\(feedURL) \(uniqueID)" //Must be same as Article.articleID
		}
	}
}
