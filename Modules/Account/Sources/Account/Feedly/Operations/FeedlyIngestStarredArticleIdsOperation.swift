//
//  FeedlyIngestStarredArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import SyncDatabase
import Secrets

/// Clone locally the remote starred article state.
///
/// Typically, it pages through the article ids of the global.saved stream.
/// When all the article ids are collected, a status is created for each.
/// The article ids previously marked as starred but not collected become unstarred.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestStarredArticleIdsOperation: FeedlyOperation, @unchecked Sendable {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let database: SyncDatabase
	private var remoteEntryIds = Set<String>()

	@MainActor convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService, database: SyncDatabase, newerThan: Date?) {
		let resource = FeedlyTagResourceId.Global.saved(for: userId)
		self.init(account: account, resource: resource, service: service, database: database, newerThan: newerThan)
	}

	@MainActor init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, database: SyncDatabase, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.database = database
		super.init()
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

			remoteEntryIds.formUnion(streamIds.ids)

			guard let continuation = streamIds.continuation else {
				removeEntryIdsWithPendingStatus()
				return
			}

			getStreamIds(continuation)

		case .failure(let error):
			didComplete(with: error)
		}
	}

	/// Do not override pending statuses with the remote statuses of the same articles, otherwise an article will temporarily re-acquire the remote status before the pending status is pushed and subseqently pulled.
	private func removeEntryIdsWithPendingStatus() {
		Task { @MainActor in
			guard !isCanceled else {
				didComplete()
				return
			}

			do {
				guard let pendingArticleIDs = try await database.selectPendingStarredStatusArticleIDs() else {
					didComplete()
					return
				}
				remoteEntryIds.subtract(pendingArticleIDs)
				updateStarredStatuses()
			} catch {
				didComplete(with: error)
			}
		}
	}

	@MainActor private func updateStarredStatuses() {
		guard !isCanceled else {
			didComplete()
			return
		}

		Task { @MainActor in
			do {
				let localStarredArticleIDs = try await account.fetchStarredArticleIDsAsync()
				processStarredArticleIDs(localStarredArticleIDs)
				didComplete()
			} catch {
				didComplete(with: error)
			}
		}
	}

	@MainActor func processStarredArticleIDs(_ localStarredArticleIDs: Set<String>) {
		guard !isCanceled else {
			didComplete()
			return
		}

		Task { @MainActor in
			nonisolated(unsafe) var processingError: Error?

			let remoteStarredArticleIDs = remoteEntryIds
			let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)

			do {
				try await account.markAsStarredAsync(articleIDs: remoteStarredArticleIDs)
			} catch {
				processingError = error
			}

			do {
				try await account.markAsUnstarredAsync(articleIDs: deltaUnstarredArticleIDs)
			} catch {
				processingError = error
			}

			if let processingError {
				didComplete(with: processingError)
			} else {
				didComplete()
			}
		}
	}
}
