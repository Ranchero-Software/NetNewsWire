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
final class FeedlyIngestUnreadArticleIdsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let database: SyncDatabase
	private var remoteEntryIds = Set<String>()

	convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService, database: SyncDatabase, newerThan: Date?) {
		let resource = FeedlyCategoryResourceId.Global.all(for: userId)
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
		service.getStreamIds(for: resource, continuation: continuation, newerThan: nil, unreadOnly: true, completion: didGetStreamIds(_:))
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
				if let pendingArticleIDs = try await database.selectPendingReadStatusArticleIDs() {
					remoteEntryIds.subtract(pendingArticleIDs)
					updateUnreadStatuses()
				}

			} catch {
				didFinish(with: error)
			}
		}
	}

	private func updateUnreadStatuses() {
		guard !isCanceled else {
			didFinish()
			return
		}

		account.fetchUnreadArticleIDs { result in
			switch result {
			case .success(let localUnreadArticleIDs):
				self.processUnreadArticleIDs(localUnreadArticleIDs)

			case .failure(let error):
				self.didFinish(with: error)
			}
		}
	}

	private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) {
		guard !isCanceled else {
			didFinish()
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
				self.didFinish()
				return
			}
			self.didFinish(with: error)
		}
	}
}
