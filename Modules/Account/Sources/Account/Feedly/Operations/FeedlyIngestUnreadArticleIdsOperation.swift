//
//  FeedlyIngestUnreadArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser
import SyncDatabase
import Secrets

/// Clone locally the remote unread article state.
///
/// Typically, it pages through the unread article ids of the global.all stream.
/// When all the unread article ids are collected, a status is created for each.
/// The article ids previously marked as unread but not collected become read.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestUnreadArticleIdsOperation: FeedlyOperation, @unchecked Sendable {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let database: SyncDatabase
	private var remoteEntryIds = Set<String>()

	@MainActor convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService, database: SyncDatabase, newerThan: Date?) {
		let resource = FeedlyCategoryResourceId.Global.all(for: userId)
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
		service.getStreamIds(for: resource, continuation: continuation, newerThan: nil, unreadOnly: true, completion: didGetStreamIds(_:))
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
				if let pendingArticleIDs = try await database.selectPendingReadStatusArticleIDs() {
					remoteEntryIds.subtract(pendingArticleIDs)
					updateUnreadStatuses()
				}

			} catch {
				didComplete(with: error)
			}
		}
	}

	@MainActor private func updateUnreadStatuses() {
		guard !isCanceled else {
			didComplete()
			return
		}

		Task { @MainActor in
			do {
				let localUnreadArticleIDs = try await account.fetchUnreadArticleIDs()
				processUnreadArticleIDs(localUnreadArticleIDs)
			} catch {
				didComplete(with: error)
			}
		}
	}

	@MainActor private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) {
		guard !isCanceled else {
			didComplete()
			return
		}

		let remoteUnreadArticleIDs = remoteEntryIds
		let group = DispatchGroup()

		final class ReadStatusResults {
			var markAsUnreadError: Error?
			var markAsReadError: Error?
		}

		let results = ReadStatusResults()

		group.enter()
		account.markAsUnread(remoteUnreadArticleIDs) { result in
			if case .failure(let error) = result {
				results.markAsUnreadError = error
			}
			group.leave()
		}

		let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
		group.enter()
		account.markAsRead(articleIDsToMarkRead) { result in
			if case .failure(let error) = result {
				results.markAsReadError = error
			}
			group.leave()
		}

		group.notify(queue: .main) {
			let markingError = results.markAsReadError ?? results.markAsUnreadError
			guard let error = markingError else {
				self.didComplete()
				return
			}
			self.didComplete(with: error)
		}
	}
}
