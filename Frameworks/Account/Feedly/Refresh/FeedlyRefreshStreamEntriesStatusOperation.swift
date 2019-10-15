//
//  FeedlyRefreshStreamEntriesStatusOperation.swift
//  Account
//
//  Created by Kiel Gillard on 25/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Single responsibility is to update the read status of articles stored locally with the unread status of the entries in a Collection's stream from Feedly.
final class FeedlyRefreshStreamEntriesStatusOperation: FeedlyOperation {
	private let account: Account
	private let entryProvider: FeedlyEntryProviding
	private let log: OSLog
	
	init(account: Account, entryProvider: FeedlyEntryProviding, log: OSLog) {
		self.account = account
		self.entryProvider = entryProvider
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		let entries = entryProvider.entries
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
		
		didFinish()
	}
}
