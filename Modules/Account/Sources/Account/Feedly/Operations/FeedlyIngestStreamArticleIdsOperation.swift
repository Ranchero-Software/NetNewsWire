//
//  FeedlyIngestStreamArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Secrets

/// Ensure a status exists for every article id the user might be interested in.
///
/// Typically, it pages through the article ids of the global.all stream.
/// As the article ids are collected, a default read status is created for each.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestStreamArticleIdsOperation: FeedlyOperation, @unchecked Sendable {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService

	@MainActor init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService) {
		self.account = account
		self.resource = resource
		self.service = service
		super.init()
	}

	@MainActor convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService) {
		let all = FeedlyCategoryResourceId.Global.all(for: userId)
		self.init(account: account, resource: all, service: service)
	}

	@MainActor override func run() {
		getStreamIds(nil)
	}

	@MainActor private func getStreamIds(_ continuation: String?) {
		service.getStreamIds(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIds(_:))
	}

	@MainActor private func didGetStreamIds(_ result: Result<FeedlyStreamIds, Error>) {
		guard !isCanceled else {
			didComplete()
			return
		}

		switch result {
		case .success(let streamIds):
			account.createStatusesIfNeeded(articleIDs: Set(streamIds.ids)) { databaseError in

				if let error = databaseError {
					self.didComplete(with: error)
					return
				}

				guard let continuation = streamIds.continuation else {
					Feedly.logger.info("Feedly: Reached end of stream for \(self.resource.id)")
					self.didComplete()
					return
				}

				self.getStreamIds(continuation)
			}
		case .failure(let error):
			didComplete(with: error)
		}
	}
}
