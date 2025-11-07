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
final class FeedlyIngestStarredArticleIdsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let database: SyncDatabase
	private var remoteEntryIds = Set<String>()

	convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService, database: SyncDatabase, newerThan: Date?) {
		let resource = FeedlyTagResourceId.Global.saved(for: userId)
		self.init(account: account, resource: resource, service: service, database: database, newerThan: newerThan)
	}

	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, database: SyncDatabase, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.database = database
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

			remoteEntryIds.formUnion(streamIds.ids)

			guard let continuation = streamIds.continuation else {
				removeEntryIdsWithPendingStatus()
				return
			}

			getStreamIds(continuation)

		case .failure(let error):
			didFinish(with: error)
		}
	}

	/// Do not override pending statuses with the remote statuses of the same articles, otherwise an article will temporarily re-acquire the remote status before the pending status is pushed and subseqently pulled.
	private func removeEntryIdsWithPendingStatus() {
		Task { @MainActor in
			guard !isCanceled else {
				didFinish()
				return
			}

			do {
				guard let pendingArticleIDs = try await database.selectPendingStarredStatusArticleIDs() else {
					didFinish()
					return
				}
				remoteEntryIds.subtract(pendingArticleIDs)
				updateStarredStatuses()
			} catch {
				didFinish(with: error)
			}
		}
	}

	private func updateStarredStatuses() {
		guard !isCanceled else {
			didFinish()
			return
		}

		account.fetchStarredArticleIDs { result in
			switch result {
			case .success(let localStarredArticleIDs):
				self.processStarredArticleIDs(localStarredArticleIDs)

			case .failure(let error):
				self.didFinish(with: error)
			}
		}
	}

	func processStarredArticleIDs(_ localStarredArticleIDs: Set<String>) {
		guard !isCanceled else {
			didFinish()
			return
		}

		let remoteStarredArticleIDs = remoteEntryIds

		let group = DispatchGroup()

		final class StarredStatusResults {
			var markAsStarredError: Error?
			var markAsUnstarredError: Error?
		}

		let results = StarredStatusResults()

		group.enter()
		account.markAsStarred(remoteStarredArticleIDs) { result in
			if case .failure(let error) = result {
				results.markAsStarredError = error
			}
			group.leave()
		}

		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
		group.enter()
		account.markAsUnstarred(deltaUnstarredArticleIDs) { result in
			if case .failure(let error) = result {
				results.markAsUnstarredError = error
			}
			group.leave()
		}

		group.notify(queue: .main) {
			let markingError = results.markAsStarredError ?? results.markAsUnstarredError
			guard let error = markingError else {
				self.didFinish()
				return
			}
			self.didFinish(with: error)
		}
	}
}
