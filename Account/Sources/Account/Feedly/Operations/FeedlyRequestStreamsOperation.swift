//
//  FeedlyRequestStreamsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyRequestStreamsOperationDelegate: AnyObject {
	func feedlyRequestStreamsOperation(_ operation: FeedlyRequestStreamsOperation, enqueue collectionStreamOperation: FeedlyGetStreamContentsOperation)
}

/// Create one stream request operation for one Feedly collection.
/// This is the start of the process of refreshing the entire contents of a Folder.
final class FeedlyRequestStreamsOperation: FeedlyOperation {
	
	weak var queueDelegate: FeedlyRequestStreamsOperationDelegate?
	
	let collectionsProvider: FeedlyCollectionProviding
	let service: FeedlyGetStreamContentsService
	let account: Account
	let log: OSLog
	let newerThan: Date?
	let unreadOnly: Bool?

	init(account: Account, collectionsProvider: FeedlyCollectionProviding, newerThan: Date?, unreadOnly: Bool?, service: FeedlyGetStreamContentsService, log: OSLog) {
		self.account = account
		self.service = service
		self.collectionsProvider = collectionsProvider
		self.newerThan = newerThan
		self.unreadOnly = unreadOnly
		self.log = log
	}
	
	override func run() {
		defer {
			didFinish()
		}
		
		assert(queueDelegate != nil, "This is not particularly useful unless the `queueDelegate` is non-nil.")
		
		// TODO: Prioritise the must read collection/category before others so the most important content for the user loads first.
		
		for collection in collectionsProvider.collections {
			let resource = FeedlyCategoryResourceId(id: collection.id)
			let operation = FeedlyGetStreamContentsOperation(account: account,
															   resource: resource,
															   service: service,
															   newerThan: newerThan,
															   unreadOnly: unreadOnly,
															   log: log)
			queueDelegate?.feedlyRequestStreamsOperation(self, enqueue: operation)
		}
		
		os_log(.debug, log: log, "Requested %i collection streams", collectionsProvider.collections.count)
	}
}
