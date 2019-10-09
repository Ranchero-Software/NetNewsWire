//
//  FeedlyArticleStatusCoordinator.swift
//  Account
//
//  Created by Kiel Gillard on 24/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SyncDatabase
import Articles
import os.log

final class FeedlyArticleStatusCoordinator {
	private let database: SyncDatabase
	private let log: OSLog
	private let caller: FeedlyAPICaller
	
	init(dataFolderPath: String, caller: FeedlyAPICaller, log: OSLog) {
		let databaseFilePath = (dataFolderPath as NSString).appendingPathComponent("Sync.sqlite3")
		self.database = SyncDatabase(databaseFilePath: databaseFilePath)
		self.log = log
		self.caller = caller
	}
	
	/// Stores a status for a particular article locally.
	func articles(_ articles: Set<Article>, for account: Account, didChangeStatus statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		
		let syncStatuses = articles.map { article in
			return SyncStatus(articleID: article.articleID, key: statusKey, flag: flag)
		}
		
		database.insertStatuses(syncStatuses)
		os_log(.debug, log: log, "Marking %@ as %@.", articles.map { $0.title }, syncStatuses)
		
		if database.selectPendingCount() > 100 {
			sendArticleStatus(for: account)
		}
		
		return account.update(articles, statusKey: statusKey, flag: flag)
	}
	
	/// Ensures local articles have the same status as they do remotely.
	func refreshArticleStatus(for account: Account, entries: [FeedlyEntry], completion: @escaping (() -> Void)) {
		
		let unreadArticleIds = Set(entries.filter { $0.unread }.map { $0.id })
		
		// Mark articles as unread
		let currentUnreadArticleIDs = account.fetchUnreadArticleIDs()
		let deltaUnreadArticleIDs = unreadArticleIds.subtracting(currentUnreadArticleIDs)
		let markUnreadArticles = account.fetchArticles(.articleIDs(deltaUnreadArticleIDs))
		account.update(markUnreadArticles, statusKey: .read, flag: false)
		
		let readAritcleIds = Set(entries.filter { !$0.unread }.map { $0.id })
		
		let deltaReadArticleIDs = currentUnreadArticleIDs.intersection(readAritcleIds)
		let markReadArticles = account.fetchArticles(.articleIDs(deltaReadArticleIDs))
		account.update(markReadArticles, statusKey: .read, flag: true)
		
//		os_log(.debug, log: log, "\"%@\" - updated %i UNREAD and %i read article(s).", collection.label, unreadArticleIds.count, markReadArticles.count)
		
		completion()
		
		// TODO: starred
		
//		group.enter()
//		caller.retrieveStarredEntries() { result in
//			switch result {
//			case .success(let articleIDs):
//				self.syncArticleStarredState(account: account, articleIDs: articleIDs)
//				group.leave()
//			case .failure(let error):
//				os_log(.info, log: self.log, "Retrieving starred entries failed: %@.", error.localizedDescription)
//				group.leave()
//			}
//
//		}
		
	}
	
	/// Ensures remote articles have the same status as they do locally.
	func sendArticleStatus(for account: Account, completion: (() -> Void)? = nil) {
		os_log(.debug, log: log, "Sending article statuses...")
		
		let pending = database.selectForProcessing()
		
		let statuses: [(status: ArticleStatus.Key, flag: Bool, action: FeedlyAPICaller.MarkAction)] = [
			(.read, false, .unread),
			(.read, true, .read),
			(.starred, true, .saved),
			(.starred, false, .unsaved),
		]
		
		let group = DispatchGroup()
		
		for pairing in statuses {
			let articleIds = pending.filter { $0.key == pairing.status && $0.flag == pairing.flag }
			guard !articleIds.isEmpty else {
				continue
			}
			
			let ids = Set(articleIds.map { $0.articleID })
			let database = self.database
			group.enter()
			caller.mark(ids, as: pairing.action) { result in
				switch result {
				case .success:
					database.deleteSelectedForProcessing(Array(ids))
				case .failure:
					database.resetSelectedForProcessing(Array(ids))
				}
				group.leave()
			}
		}
		
		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done sending article statuses.")
			completion?()
		}
	}
}
