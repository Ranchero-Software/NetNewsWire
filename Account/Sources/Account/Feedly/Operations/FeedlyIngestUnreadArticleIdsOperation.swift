//
//  FeedlyIngestUnreadArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
///Users/brent/Projects/NetNewsWire/Account/Sources/Account/Feedly/Operations/FeedlyIngestUnreadArticleIDsOperation.swift

import Foundation
import RSCore
import RSParser
import SyncDatabase
import Secrets

/// Clone locally the remote unread article state.
///
/// Typically, it pages through the unread article ids of the global.all stream.
/// When all the unread article ids are collected, a status is created for each.
/// The article ids previously marked as unread but not collected become read.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestUnreadArticleIdsOperation: FeedlyOperation, Logging {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIDsService
	private let database: SyncDatabase
	private var remoteEntryIDs = Set<String>()
	
	convenience init(account: Account, userID: String, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?) {
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
		self.init(account: account, resource: resource, service: service, database: database, newerThan: newerThan)
	}
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.database = database
	}
	
	override func run() {
		getStreamIDs(nil)
	}
	
	private func getStreamIDs(_ continuation: String?) {
		service.streamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: true, completion: didGetStreamIDs(_:))
	}
	
	private func didGetStreamIDs(_ result: Result<FeedlyStreamIDs, Error>) {
		guard !isCanceled else {
			didFinish()
			return
		}
		
		switch result {
		case .success(let streamIDs):
			
			remoteEntryIDs.formUnion(streamIDs.ids)
			
			guard let continuation = streamIDs.continuation else {
				removeEntryIDsWithPendingStatus()
				return
			}
			
			getStreamIDs(continuation)
			
		case .failure(let error):
			didFinish(with: error)
		}
	}
	
	/// Do not override pending statuses with the remote statuses of the same articles, otherwise an article will temporarily re-acquire the remote status before the pending status is pushed and subseqently pulled.
	private func removeEntryIDsWithPendingStatus() {
		guard !isCanceled else {
			didFinish()
			return
		}

		Task { @MainActor in
			do {
				let pendingArticleIDs = try await database.selectPendingReadArticleIDs()
				self.remoteEntryIDs.subtract(pendingArticleIDs)
				self.updateUnreadStatuses()
			} catch {
				self.didFinish(with: error)
			}
		}
	}
	
	private func updateUnreadStatuses() {
		guard !isCanceled else {
			didFinish()
			return
		}

        Task { @MainActor in
            var localUnreadArticleIDs: Set<String>?

            do {
                localUnreadArticleIDs = try await account.fetchUnreadArticleIDs()
            } catch {
                didFinish(with: error)
                return
            }

            if let localUnreadArticleIDs {
                await processUnreadArticleIDs(localUnreadArticleIDs)
            }
        }
	}
	
	@MainActor private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) async {
        guard !isCanceled else {
            didFinish()
            return
        }

		let remoteUnreadArticleIDs = remoteEntryIDs

        do {
            try await account.markArticleIDsAsUnread(remoteUnreadArticleIDs)

            let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
            try await account.markArticleIDsAsRead(articleIDsToMarkRead)

            didFinish()
        } catch let error {
            didFinish(with: error)
        }
	}
}
