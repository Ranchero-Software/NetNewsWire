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
	
	var cachedStatuses = [String: ArticleStatus]()
	let name: String
	
	init(name: String) {
		
		self.name = name
	}
	
	func markArticles(_ articles: Set<Article>, statusKey: String, flag: Bool) {
		
		assertNoMissingStatuses(articles)
		let statuses = Set(articles.flatMap { $0.status })
		markArticleStatuses(statuses, statusKey: statusKey, flag: flag)
	}

	func attachCachedStatuses(_ articles: Set<Article>) {
		
		articles.forEach { (oneArticle) in
			
			if let cachedStatus = cachedStatusForArticleID(oneArticle.articleID) {
				oneArticle.status = cachedStatus
			}
			else if let oneArticleStatus = oneArticle.status {
				cacheStatus(oneArticleStatus)
			}
		}
	}
	
	func ensureStatusesForParsedArticles(_ parsedArticles: [ParsedItem], _ callback: @escaping RSVoidCompletionBlock) {
		
		var articleIDs = Set(parsedArticles.map { $0.articleID })
		articleIDs = articleIDsMissingStatuses(articleIDs)
		if articleIDs.isEmpty {
			callback()
			return
		}
		
		queue.fetch { (database: FMDatabase!) -> Void in
			
			let statuses = self.fetchStatusesForArticleIDs(articleIDs, database: database)
			
			DispatchQueue.main.async {
				
				self.cacheStatuses(statuses)
				
				let newArticleIDs = self.articleIDsMissingStatuses(articleIDs)
				self.createStatusForNewArticleIDs(newArticleIDs)
				callback()
			}
		}
	}

	func assertNoMissingStatuses(_ articles: Set<Article>) {
		
		for oneArticle in articles {
			if oneArticle.status == nil {
				assertionFailure("All articles must have a status at this point.")
				return
			}
		}
	}
}

// MARK: - Private

private let statusesTableName = "statuses"

private extension StatusesManager {
	
	// MARK: Marking
	
	func markArticleStatuses(_ statuses: Set<ArticleStatus>, statusKey: String, flag: Bool) {
		
		// Ignore the statuses where status.[statusKey] == flag. Update the remainder and save in database.
		
		var articleIDs = Set<String>()
		
		statuses.forEach { (oneStatus) in
			
			if oneStatus.boolStatus(forKey: statusKey) != flag {
				oneStatus.setBoolStatus(flag, forKey: statusKey)
				articleIDs.insert(oneStatus.articleID)
			}
		}
		
		if !articleIDs.isEmpty {
			updateArticleStatusesInDatabase(articleIDs, statusKey: statusKey, flag: flag)
		}
	}

	// MARK: Fetching
	
	func fetchStatusesForArticleIDs(_ articleIDs: Set<String>, database: FMDatabase) -> Set<ArticleStatus> {
		
		guard !articleIDs.isEmpty else {
			return Set<ArticleStatus>()
		}
		
		guard let resultSet = database.rs_selectRowsWhereKey(DatabaseKey.articleID, inValues: Array(articleIDs), tableName: statusesTableName) else {
			return Set<ArticleStatus>()
		}
		
		return articleStatusesWithResultSet(resultSet)
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
	
	// MARK: Saving
	
	func saveStatuses(_ statuses: Set<ArticleStatus>) {
		
		let statusArray = statuses.map { (oneStatus) -> NSDictionary in
			return oneStatus.databaseDictionary()
		}
		
		queue.update { (database: FMDatabase!) -> Void in
			
			statusArray.forEach { (oneStatusDictionary) in
				
				let _ = database.rs_insertRow(with: oneStatusDictionary as [NSObject: AnyObject], insertType: RSDatabaseInsertOrIgnore, tableName: "statuses")
			}
		}
	}
	
	private func updateArticleStatusesInDatabase(_ articleIDs: Set<String>, statusKey: ArticleStatusKey, flag: Bool) {
		
		queue.update { (database: FMDatabase!) -> Void in
			
			let _ = database.rs_updateRows(withValue: NSNumber(value: flag), valueKey: statusKey.rawValue, whereKey: articleIDKey, inValues: Array(articleIDs), tableName: statusesTableName)
		}
	}
	
	// MARK: Creating
	
	func createStatusForNewArticleIDs(_ articleIDs: Set<String>) {

		let now = Date()
		let statuses = articleIDs.map { (oneArticleID) -> LocalArticleStatus in
			return ArticleStatus(articleID: oneArticleID, read: false, starred: false, userDeleted: false, dateArrived: now)
		}
		cacheStatuses(Set(statuses))

		queue.update { (database: FMDatabase!) -> Void in

			let falseValue = NSNumber(value: false)

			articleIDs.forEach { (oneArticleID) in

				let _ = database.executeUpdate("insert or ignore into  statuses (read, articleID, starred, userDeleted, dateArrived) values (?, ?, ?, ?, ?)", withArgumentsIn:[falseValue, oneArticleID as NSString, falseValue, falseValue, now])
			}
		}
	}

	// MARK: Cache
	
	func cachedStatusForArticleID(_ articleID: String) -> ArticleStatus? {
		
		return cachedStatuses[articleID]
	}
	
	func cacheStatus(_ status: ArticleStatus) {
		
		cacheStatuses(Set([status]))
	}
	
	func cacheStatuses(_ statuses: Set<ArticleStatus>) {
		
		statuses.forEach { (oneStatus) in
			if let _ = cachedStatuses[oneStatus.articleID] {
				return
			}
			cachedStatuses[oneStatus.articleID] = oneStatus
		}
	}
	
	// MARK: Utilities
	
	func articleIDsMissingStatuses(_ articleIDs: Set<String>) -> Set<String> {
		
		return Set(articleIDs.filter { cachedStatusForArticleID($0) == nil })
	}
}

extension ParsedItem {

	var articleID: String {
		get {
			return "\(feedURL) \(uniqueID)" //Must be same as Article.articleID
		}
	}
}
