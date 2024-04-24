//
//  FeedlyIngestStarredArticleIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import SyncDatabase
import Secrets
import Feedly

/// Clone locally the remote starred article state.
///
/// Typically, it pages through the article ids of the global.saved stream.
/// When all the article ids are collected, a status is created for each.
/// The article ids previously marked as starred but not collected become unstarred.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestStarredArticleIDsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceID
	private let service: FeedlyGetStreamIDsService
	private let database: SyncDatabase
	private var remoteEntryIDs = Set<String>()
	private let log: OSLog
	
	convenience init(account: Account, userID: String, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?, log: OSLog) {
		let resource = FeedlyTagResourceID.Global.saved(for: userID)
		self.init(account: account, resource: resource, service: service, database: database, newerThan: newerThan, log: log)
	}
	
	init(account: Account, resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.database = database
		self.log = log
	}
	
	override func run() {
		getStreamIDs(nil)
	}
	
	private func getStreamIDs(_ continuation: String?) {

		Task { @MainActor in

			do {
				let streamIDs = try await service.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil)
				remoteEntryIDs.formUnion(streamIDs.ids)

				guard let continuation = streamIDs.continuation else {
					try await removeEntryIDsWithPendingStatus()
					didFinish()
					return
				}

				getStreamIDs(continuation)

			} catch {
				didFinish(with: error)
			}
		}
	}
	
	/// Do not override pending statuses with the remote statuses of the same articles, otherwise an article will temporarily re-acquire the remote status before the pending status is pushed and subseqently pulled.
	private func removeEntryIDsWithPendingStatus() async throws {

		if let pendingArticleIDs = try await database.selectPendingStarredStatusArticleIDs() {
			remoteEntryIDs.subtract(pendingArticleIDs)
		}
		try await updateStarredStatuses()
	}

	private func updateStarredStatuses() async throws {

		if let localStarredArticleIDs = try await account.fetchStarredArticleIDs() {
			try await processStarredArticleIDs(localStarredArticleIDs)
		}
	}

	func processStarredArticleIDs(_ localStarredArticleIDs: Set<String>) async throws {

		var markAsStarredError: Error?
		var markAsUnstarredError: Error?

		let remoteStarredArticleIDs = remoteEntryIDs
		do {
			try await account.markAsStarred(remoteStarredArticleIDs)
		} catch {
			markAsStarredError = error
		}

		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
		do {
			try await account.markAsUnstarred(deltaUnstarredArticleIDs)
		} catch {
			markAsUnstarredError = error
		}

		if let markingError = markAsStarredError ?? markAsUnstarredError {
			throw markingError
		}
	}
}
