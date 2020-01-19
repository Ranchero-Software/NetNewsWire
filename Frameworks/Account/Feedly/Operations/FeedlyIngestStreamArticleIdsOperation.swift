//
//  FeedlyIngestStreamArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Ensure a status exists for every article id the user might be interested in.
///
/// Typically, it pages through the article ids of the global.all stream.
/// As the article ids are collected, a default read status is created for each.
/// So this operation has side effects *for the entire account* it operates on.
class FeedlyIngestStreamArticleIdsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let log: OSLog
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.log = log
	}
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamIdsService, log: OSLog) {
		let all = FeedlyCategoryResourceId.Global.all(for: credentials.username)
		self.init(account: account, resource: all, service: service, log: log)
	}
	
	override func run() {
		getStreamIds(nil)
	}
	
	private func getStreamIds(_ continuation: String?) {
		service.getStreamIds(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIds(_:))
	}
	
	private func didGetStreamIds(_ result: Result<FeedlyStreamIds, Error>) {
		guard !isCanceled else {
			didFinish()
			return
		}
		
		switch result {
		case .success(let streamIds):
			account.createStatusesIfNeeded(articleIDs: Set(streamIds.ids)) { databaseError in
				
				if let error = databaseError {
					self.didFinish(with: error)
					return
				}
				
				guard let continuation = streamIds.continuation else {
					os_log(.debug, log: self.log, "Reached end of stream for %@", self.resource.id)
					self.didFinish()
					return
				}
				
				self.getStreamIds(continuation)
			}
		case .failure(let error):
			didFinish(with: error)
		}
	}
}
