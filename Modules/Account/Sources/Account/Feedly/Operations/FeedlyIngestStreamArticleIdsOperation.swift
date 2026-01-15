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
final class FeedlyIngestStreamArticleIdsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService

	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService) {
		self.account = account
		self.resource = resource
		self.service = service
	}

	convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService) {
		let all = FeedlyCategoryResourceId.Global.all(for: userId)
		self.init(account: account, resource: all, service: service)
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

		Task {
			switch result {
			case .success(let streamIds):
				do {
					try await account.createStatusesIfNeededAsync(articleIDs: Set(streamIds.ids))
					guard let continuation = streamIds.continuation else {
						Feedly.logger.info("Feedly: Reached end of stream for \(self.resource.id)")
						self.didFinish()
						return
					}
					self.getStreamIds(continuation)
				} catch {
					self.didFinish(with: error)
				}
			case .failure(let error):
				self.didFinish(with: error)
			}
		}
	}
}
