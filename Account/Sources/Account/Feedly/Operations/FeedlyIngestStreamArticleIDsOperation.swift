//
//  FeedlyIngestStreamArticleIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Secrets
import Database
import Feedly

/// Ensure a status exists for every article id the user might be interested in.
///
/// Typically, it pages through the article ids of the global.all stream.
/// As the article ids are collected, a default read status is created for each.
/// So this operation has side effects *for the entire account* it operates on.
class FeedlyIngestStreamArticleIDsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceID
	private let service: FeedlyGetStreamIDsService
	private let log: OSLog
	
	init(account: Account, resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.log = log
	}
	
	convenience init(account: Account, userID: String, service: FeedlyGetStreamIDsService, log: OSLog) {
		let all = FeedlyCategoryResourceID.Global.all(for: userID)
		self.init(account: account, resource: all, service: service, log: log)
	}
	
	override func run() {
		getStreamIDs(nil)
	}
	
	private func getStreamIDs(_ continuation: String?) {
		service.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIDs(_:))
	}
	
	private func didGetStreamIDs(_ result: Result<FeedlyStreamIDs, Error>) {
		guard !isCanceled else {
			didFinish()
			return
		}

		switch result {
		case .success(let streamIDs):

			Task { @MainActor in
				do {
					try await account.createStatusesIfNeeded(articleIDs: Set(streamIDs.ids))

					guard let continuation = streamIDs.continuation else {
						os_log(.debug, log: self.log, "Reached end of stream for %@", self.resource.id)
						self.didFinish()
						return
					}

					self.getStreamIDs(continuation)
				} catch {
					self.didFinish(with: error)
					return
				}
			}
		case .failure(let error):
			didFinish(with: error)
		}
	}
}
