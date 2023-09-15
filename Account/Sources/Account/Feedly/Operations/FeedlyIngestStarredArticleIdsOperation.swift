//
//  FeedlyIngestStarredArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import SyncDatabase
import Secrets

/// Clone locally the remote starred article state.
///
/// Typically, it pages through the article ids of the global.saved stream.
/// When all the article ids are collected, a status is created for each.
/// The article ids previously marked as starred but not collected become unstarred.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestStarredArticleIdsOperation: FeedlyOperation, Logging {

	private let account: Account
	private let resource: FeedlyResourceID
	private let service: FeedlyGetStreamIDsService
	private let database: SyncDatabase
	private var remoteEntryIds = Set<String>()
	
	convenience init(account: Account, userId: String, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?) {
		let resource = FeedlyTagResourceID.Global.saved(for: userId)
		self.init(account: account, resource: resource, service: service, database: database, newerThan: newerThan)
	}
	
	init(account: Account, resource: FeedlyResourceID, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.database = database
	}
	
	override func run() {
		getStreamIds(nil)
	}
	
	private func getStreamIds(_ continuation: String?) {
		service.streamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIds(_:))
	}
	
	private func didGetStreamIds(_ result: Result<FeedlyStreamIDs, Error>) {
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
		guard !isCanceled else {
			didFinish()
			return
		}
		
		Task { @MainActor in
			do {
				let pendingArticleIDs = try await database.selectPendingStarredArticleIDs()
				self.remoteEntryIds.subtract(pendingArticleIDs)
				self.updateStarredStatuses()
			} catch {
				self.didFinish(with: error)
			}
		}
	}
	
	private func updateStarredStatuses() {
		guard !isCanceled else {
			didFinish()
			return
		}

        Task { @MainActor in

            var localStarredArticleIDs: Set<String>?

            do {
                localStarredArticleIDs = try await account.fetchStarredArticleIDs()
            } catch {
                didFinish(with: error)
                return
            }

            if let localStarredArticleIDs {
                processStarredArticleIDs(localStarredArticleIDs)
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
		account.markAsStarred(remoteStarredArticleIDs) { databaseError in
			if let databaseError = databaseError {
				results.markAsStarredError = databaseError
			}
			group.leave()
		}

		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
		group.enter()
		account.markAsUnstarred(deltaUnstarredArticleIDs) { databaseError in
			if let databaseError = databaseError {
				results.markAsUnstarredError = databaseError
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
