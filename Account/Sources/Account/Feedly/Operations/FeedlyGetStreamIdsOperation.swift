//
//  FeedlyGetStreamIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

protocol FeedlyGetStreamIdsOperationDelegate: AnyObject {
	func feedlyGetStreamIdsOperation(_ operation: FeedlyGetStreamIdsOperation, didGet streamIds: FeedlyStreamIDs)
}

/// Single responsibility is to get the stream ids from Feedly.
final class FeedlyGetStreamIdsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, Logging {
	
	var entryIDs: Set<String> {
		guard let ids = streamIds?.ids else {
			assertionFailure("Has this operation been addeded as a dependency on the caller?")
			return []
		}
		return Set(ids)
	}
	
	private(set) var streamIds: FeedlyStreamIDs?
	
	let account: Account
	let service: FeedlyGetStreamIDsService
	let continuation: String?
	let resource: FeedlyResourceID
	let unreadOnly: Bool?
	let newerThan: Date?

	init(account: Account, resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, continuation: String? = nil, newerThan: Date? = nil, unreadOnly: Bool?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.continuation = continuation
		self.newerThan = newerThan
		self.unreadOnly = unreadOnly
	}
	
	weak var streamIdsDelegate: FeedlyGetStreamIdsOperationDelegate?
	
	override func run() {
		service.streamIDs(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly) { result in
			switch result {
			case .success(let stream):
				self.streamIds = stream
				
				self.streamIdsDelegate?.feedlyGetStreamIdsOperation(self, didGet: stream)
				
				self.didFinish()
				
			case .failure(let error):
                self.logger.error("Unable to get stream ids: \(error.localizedDescription, privacy: .public)")
				self.didFinish(with: error)
			}
		}
	}
}
