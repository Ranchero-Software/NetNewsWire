//
//  FeedlySendArticleStatusesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 14/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import SyncDatabase
import os.log

/// Single responsibility is to update or ensure articles from the entry provider are the only starred articles.
final class FeedlySendArticleStatusesOperation: FeedlyOperation {
	private let database: SyncDatabase
	private let log: OSLog
	private let caller: FeedlyAPICaller
	
	init(database: SyncDatabase, caller: FeedlyAPICaller, log: OSLog) {
		self.database = database
		self.caller = caller
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else {
			return
		}
		
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
			self.didFinish()
		}
	}
}
