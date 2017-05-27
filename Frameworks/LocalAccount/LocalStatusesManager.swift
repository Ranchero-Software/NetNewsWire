 //
//  LocalStatusesManager.swift
//  Evergreen
//
//  Created by Brent Simmons on 5/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSDatabase
import RSXML
import DataModel

final class LocalStatusesManager {
	
	var cachedStatuses = [String: LocalArticleStatus]()
	let queue: RSDatabaseQueue
	
	init(queue: RSDatabaseQueue) {
		
		self.queue = queue
	}
	
	func markArticles(_ articles: Set<LocalArticle>, statusKey: ArticleStatusKey, flag: Bool) {
		
		assertNoMissingStatuses(articles)
		let statusArray = articles.map { $0.status! as! LocalArticleStatus }
		let statuses = Set(statusArray)
		markArticleStatuses(statuses, statusKey: statusKey, flag: flag)
	}

	func attachCachedUniqueStatuses(_ articles: Set<LocalArticle>) {
		
		articles.forEach { (oneLocalArticle) in
			
			if let cachedStatus = cachedStatusForArticleID(oneLocalArticle.articleID) {
				oneLocalArticle.status = cachedStatus
			}
			else if let oneLocalArticleStatus = oneLocalArticle.status as? LocalArticleStatus {
				cacheStatus(oneLocalArticleStatus)
			}
		}
	}
	
	func ensureStatusesForParsedArticles(_ parsedArticles: Set<RSParsedArticle>, _ callback: @escaping RSVoidCompletionBlock) {
		
		var articleIDs = Set(parsedArticles.map { $0.articleID })
		articleIDs = articleIDsMissingStatuses(articleIDs)
		if articleIDs.isEmpty {
			callback()
			return
		}
		
		queue.fetch { (database: FMDatabase!) -> Void in
			
			let statuses = self.fetchStatusesForArticleIDs(articleIDs, database: database)
			
			DispatchQueue.main.async { () -> Void in
				
				self.cacheStatuses(statuses)
				
				let newArticleIDs = self.articleIDsMissingStatuses(articleIDs)
				self.createStatusForNewArticleIDs(newArticleIDs)
				callback()
			}
		}
	}

	func assertNoMissingStatuses(_ articles: Set<LocalArticle>) {
		
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

private extension LocalStatusesManager {
	
	// MARK: Marking
	
	func markArticleStatuses(_ statuses: Set<LocalArticleStatus>, statusKey: ArticleStatusKey, flag: Bool) {
		
		// Ignore the statuses where status.[statusKey] == flag. Update the remainder and save in database.
		
		var articleIDs = Set<String>()
		
		statuses.forEach { (oneStatus) in
			
			if oneStatus.boolStatusForKey(statusKey) != flag {
				oneStatus.setBoolStatusForKey(flag, articleStatusKey: statusKey)
				articleIDs.insert(oneStatus.articleID)
			}
		}
		
		if !articleIDs.isEmpty {
			updateArticleStatusesInDatabase(articleIDs, statusKey: statusKey, flag: flag)
		}
	}

	// MARK: Fetching
	
	func fetchStatusesForArticleIDs(_ articleIDs: Set<String>, database: FMDatabase) -> Set<LocalArticleStatus> {
		
		guard !articleIDs.isEmpty else {
			return Set<LocalArticleStatus>()
		}
		
		guard let resultSet = database.rs_selectRowsWhereKey(articleIDKey, inValues: Array(articleIDs), tableName: statusesTableName) else {
			return Set<LocalArticleStatus>()
		}
		
		return localArticleStatusesWithResultSet(resultSet)
	}

	func localArticleStatusesWithResultSet(_ resultSet: FMResultSet) -> Set<LocalArticleStatus> {
		
		var statuses = Set<LocalArticleStatus>()
		
		while(resultSet.next()) {
			if let oneArticleStatus = LocalArticleStatus(row: resultSet) {
				statuses.insert(oneArticleStatus)
			}
		}
		
		return statuses
	}
	
	// MARK: Saving
	
	func saveStatuses(_ statuses: Set<LocalArticleStatus>) {
		
		let statusArray = statuses.map { (oneStatus) -> NSDictionary in
			return oneStatus.databaseDictionary
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
			return LocalArticleStatus(articleID: oneArticleID, read: false, starred: false, userDeleted: false, dateArrived: now)
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
	
	func cachedStatusForArticleID(_ articleID: String) -> LocalArticleStatus? {
		
		return cachedStatuses[articleID]
	}
	
	func cacheStatus(_ status: LocalArticleStatus) {
		
		cacheStatuses(Set([status]))
	}
	
	func cacheStatuses(_ statuses: Set<LocalArticleStatus>) {
		
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

