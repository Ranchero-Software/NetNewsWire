//
//  FeedlyIngestUnreadArticleIDsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Parser
import SyncDatabase
import Secrets
import Feedly

/// Clone locally the remote unread article state.
///
/// Typically, it pages through the unread article ids of the global.all stream.
/// When all the unread article ids are collected, a status is created for each.
/// The article ids previously marked as unread but not collected become read.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestUnreadArticleIDsOperation: FeedlyOperation {

	private let account: Account
	private let resource: FeedlyResourceID
	private let service: FeedlyGetStreamIDsService
	private let database: SyncDatabase
	private var remoteEntryIDs = Set<String>()
	private let log: OSLog
	
	public convenience init(account: Account, userID: String, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?, log: OSLog) {
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		self.init(account: account, resource: resource, service: service, database: database, newerThan: newerThan, log: log)
	}
	
	public init(account: Account, resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?, log: OSLog) {
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
				let streamIDs = try await service.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: true)
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

		if let pendingArticleIDs = try await database.selectPendingReadStatusArticleIDs() {
			remoteEntryIDs.subtract(pendingArticleIDs)
		}
		try await updateUnreadStatuses()
	}

	private func updateUnreadStatuses() async throws {

		if let localUnreadArticleIDs = try await account.fetchUnreadArticleIDs() {
			try await processUnreadArticleIDs(localUnreadArticleIDs)
		}
	}

	private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) async throws {

		let remoteUnreadArticleIDs = remoteEntryIDs

		var markAsUnreadError: Error?
		var markAsReadError: Error?

		do {
			try await account.markAsUnread(remoteUnreadArticleIDs)
		} catch {
			markAsUnreadError = error
		}

		let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
		do {
			try await account.markAsRead(articleIDsToMarkRead)
		} catch {
			markAsReadError = error
		}

		if let markingError = markAsReadError ?? markAsUnreadError {
			throw markingError
		}
	}
}
