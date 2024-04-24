//
//  FeedlyGetStreamIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

public protocol FeedlyGetStreamIDsOperationDelegate: AnyObject {

	func feedlyGetStreamIDsOperation(_ operation: FeedlyGetStreamIDsOperation, didGet streamIDs: FeedlyStreamIDs)
}

/// Single responsibility is to get the stream ids from Feedly.
public final class FeedlyGetStreamIDsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding {
	
	public var entryIDs: Set<String> {
		guard let ids = streamIDs?.ids else {
			assertionFailure("Has this operation been addeded as a dependency on the caller?")
			return []
		}
		return Set(ids)
	}
	
	private(set) var streamIDs: FeedlyStreamIDs?
	
	let service: FeedlyGetStreamIDsService
	let continuation: String?
	let resource: FeedlyResourceID
	let unreadOnly: Bool?
	let newerThan: Date?
	let log: OSLog

	init(resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, continuation: String? = nil, newerThan: Date? = nil, unreadOnly: Bool?, log: OSLog) {

		self.resource = resource
		self.service = service
		self.continuation = continuation
		self.newerThan = newerThan
		self.unreadOnly = unreadOnly
		self.log = log
	}
	
	weak var streamIDsDelegate: FeedlyGetStreamIDsOperationDelegate?
	
	public override func run() {

		Task { @MainActor in

			do {
				let stream = try await service.getStreamIDs(for: resource, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly)
				self.streamIDs = stream
				self.streamIDsDelegate?.feedlyGetStreamIDsOperation(self, didGet: stream)
				self.didFinish()
			} catch {
				os_log(.debug, log: self.log, "Unable to get stream ids: %{public}@.", error as NSError)
				self.didFinish(with: error)
			}
		}
	}
}
