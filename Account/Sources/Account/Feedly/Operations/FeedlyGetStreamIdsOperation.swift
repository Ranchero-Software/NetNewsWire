//
//  FeedlyGetStreamIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

protocol FeedlyGetStreamIdsOperationDelegate: AnyObject {
	func feedlyGetStreamIdsOperation(_ operation: FeedlyGetStreamIdsOperation, didGet streamIds: FeedlyStreamIds)
}

/// Single responsibility is to get the stream ids from Feedly.
final class FeedlyGetStreamIdsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, Logging {
	
	var entryIds: Set<String> {
		guard let ids = streamIds?.ids else {
			assertionFailure("Has this operation been addeded as a dependency on the caller?")
			return []
		}
		return Set(ids)
	}
	
	private(set) var streamIds: FeedlyStreamIds?
	
	let account: Account
	let service: FeedlyGetStreamIdsService
	let continuation: String?
	let resource: FeedlyResourceId
	let unreadOnly: Bool?
	let newerThan: Date?

	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, continuation: String? = nil, newerThan: Date? = nil, unreadOnly: Bool?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.continuation = continuation
		self.newerThan = newerThan
		self.unreadOnly = unreadOnly
	}
	
	weak var streamIdsDelegate: FeedlyGetStreamIdsOperationDelegate?
	
	override func run() {
		service.getStreamIds(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly) { result in
			switch result {
			case .success(let stream):
				self.streamIds = stream
				
				self.streamIdsDelegate?.feedlyGetStreamIdsOperation(self, didGet: stream)
				
				self.didFinish()
				
			case .failure(let error):
                self.logger.error("Unable to get stream ids: \(error.localizedDescription)")
				self.didFinish(with: error)
			}
		}
	}
}
