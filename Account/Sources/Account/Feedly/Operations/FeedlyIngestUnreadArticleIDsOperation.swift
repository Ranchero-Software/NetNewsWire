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
	
	convenience init(account: Account, userID: String, service: FeedlyGetStreamIDsService, database: SyncDatabase, newerThan: Date?, log: OSLog) {
		let resource = FeedlyCategoryResourceID.Global.all(for: userID)
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
		service.getStreamIDs(for: resource, continuation: continuation, newerThan: nil, unreadOnly: true, completion: didGetStreamIDs(_:))
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
				if let pendingArticleIDs = try await self.database.selectPendingReadStatusArticleIDs() {
					self.remoteEntryIDs.subtract(pendingArticleIDs)
				}
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

			do {
				if let localUnreadArticleIDs = try await account.fetchUnreadArticleIDs() {
					self.processUnreadArticleIDs(localUnreadArticleIDs)
				}
			} catch {
				self.didFinish(with: error)
			}
		}
	}

	private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) {

		guard !isCanceled else {
			didFinish()
			return
		}

		let remoteUnreadArticleIDs = remoteEntryIDs

		Task { @MainActor in

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
				self.didFinish(with: markingError)
			}

			self.didFinish()
		}
	}
}
