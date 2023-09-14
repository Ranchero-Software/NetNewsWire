//
//  FeedlyIngestStreamArticleIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Secrets

/// Ensure a status exists for every article id the user might be interested in.
///
/// Typically, it pages through the article ids of the global.all stream.
/// As the article ids are collected, a default read status is created for each.
/// So this operation has side effects *for the entire account* it operates on.
class FeedlyIngestStreamArticleIDsOperation: FeedlyOperation, Logging {

	private let account: Account
	private let resource: FeedlyResourceID
	private let service: FeedlyGetStreamIDsService
	
	init(account: Account, resource: FeedlyResourceID, service: FeedlyGetStreamIDsService) {
		self.account = account
		self.resource = resource
		self.service = service
	}
	
	convenience init(account: Account, userId: String, service: FeedlyGetStreamIDsService) {
		let all = FeedlyCategoryResourceID.Global.all(for: userId)
		self.init(account: account, resource: all, service: service)
	}
	
	override func run() {
		getStreamIds(nil)
	}
	
	private func getStreamIds(_ continuation: String?) {
		service.streamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIds(_:))
	}
	
	private func didGetStreamIds(_ result: Result<FeedlyStreamIDs, Error>) {
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
                    self.logger.debug("Reached end of stream: \(self.resource.id, privacy: .public).")
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
