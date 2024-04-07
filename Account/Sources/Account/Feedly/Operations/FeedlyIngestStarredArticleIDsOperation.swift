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
		service.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIDs(_:))
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
				if let pendingArticleIDs = try await self.database.selectPendingStarredStatusArticleIDs() {
					self.remoteEntryIDs.subtract(pendingArticleIDs)
				}
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

			do {
				if let localStarredArticleIDs = try await account.fetchStarredArticleIDs() {
					self.processStarredArticleIDs(localStarredArticleIDs)
				}
			} catch {
				self.didFinish(with: error)
			}
		}
	}

	func processStarredArticleIDs(_ localStarredArticleIDs: Set<String>) {

		guard !isCanceled else {
			didFinish()
			return
		}

		Task { @MainActor in

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
				self.didFinish(with: markingError)
			}

			self.didFinish()
		}
	}
}
