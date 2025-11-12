//
//  FeedlyGetUpdatedArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Secrets

/// Single responsibility is to identify articles that have changed since a particular date.
///
/// Typically, it pages through the article ids of the global.all stream.
/// When all the article ids are collected, it is the responsibility of another operation to download them when appropriate.
final class FeedlyGetUpdatedArticleIdsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, @unchecked Sendable {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let newerThan: Date?

	@MainActor init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.newerThan = newerThan
		super.init()
	}

	@MainActor convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService, newerThan: Date?) {
		let all = FeedlyCategoryResourceId.Global.all(for: userId)
		self.init(account: account, resource: all, service: service, newerThan: newerThan)
	}

	var entryIds: Set<String> {
		return storedUpdatedArticleIds
	}

	private var storedUpdatedArticleIds = Set<String>()

	@MainActor override func run() {
		getStreamIds(nil)
	}

	@MainActor private func getStreamIds(_ continuation: String?) {
		guard let date = newerThan else {
			Feedly.logger.debug("Feedly: No date provided so everything must be new (nothing is updated)")
			didComplete()
			return
		}

		service.getStreamIds(for: resource, continuation: continuation, newerThan: date, unreadOnly: nil, completion: didGetStreamIds(_:))
	}

	@MainActor private func didGetStreamIds(_ result: Result<FeedlyStreamIds, Error>) {
		guard !isCanceled else {
			didComplete()
			return
		}

		switch result {
		case .success(let streamIds):
			storedUpdatedArticleIds.formUnion(streamIds.ids)

			guard let continuation = streamIds.continuation else {
				Feedly.logger.info("Feedly: Articles updated since last successful sync start date: \(self.storedUpdatedArticleIds.count)")
				didComplete()
				return
			}

			getStreamIds(continuation)

		case .failure(let error):
			didComplete(with: error)
		}
	}
}
