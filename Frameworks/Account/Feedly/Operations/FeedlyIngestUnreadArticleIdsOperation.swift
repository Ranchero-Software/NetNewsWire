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

/// Single responsibility is to clone locally the remote unread article state.
///
/// Typically, it pages through the unread article ids of the global.all stream.
/// When all the unread article ids are collected, a status is created for each.
/// The article ids previously marked as unread but not collected become read.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestUnreadArticleIdsOperation: FeedlyOperation {
	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let entryIdsProvider: FeedlyEntryIdentifierProvider
	private let log: OSLog
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		let resource = FeedlyCategoryResourceId.Global.all(for: credentials.username)
		self.init(account: account, resource: resource, service: service, newerThan: newerThan, log: log)
	}
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.entryIdsProvider = FeedlyEntryIdentifierProvider()
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		getStreamIds(nil)
	}
	
	private func getStreamIds(_ continuation: String?) {
		service.getStreamIds(for: resource, continuation: continuation, newerThan: nil, unreadOnly: true, completion: didGetStreamIds(_:))
	}
	
	private func didGetStreamIds(_ result: Result<FeedlyStreamIds, Error>) {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		switch result {
		case .success(let streamIds):
			
			entryIdsProvider.addEntryIds(in: streamIds.ids)
			
			guard let continuation = streamIds.continuation else {
				updateUnreadStatuses()
				return
			}
			
			getStreamIds(continuation)
			
		case .failure(let error):
			didFinish(error)
		}
	}
	
	private func updateUnreadStatuses() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		account.fetchUnreadArticleIDs { result in
			switch result {
			case .success(let localUnreadArticleIDs):
				self.processUnreadArticleIDs(localUnreadArticleIDs)
				
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
	
	private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) {
		guard !isCancelled else {
			didFinish()
			return
		}

		let remoteUnreadArticleIDs = entryIdsProvider.entryIds
		let group = DispatchGroup()
		
		final class ReadStatusResults {
			var markAsUnreadError: Error?
			var markAsReadError: Error?
		}
		
		let results = ReadStatusResults()
		
		group.enter()
		account.markAsUnread(remoteUnreadArticleIDs) { error in
			results.markAsUnreadError = error
			group.leave()
		}

		let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
		group.enter()
		account.markAsRead(articleIDsToMarkRead) { error in
			results.markAsReadError = error
			group.leave()
		}

		group.notify(queue: .main) {
			let markingError = results.markAsReadError ?? results.markAsUnreadError
			guard let error = markingError else {
				self.didFinish()
				return
			}
			self.didFinish(error)
		}
	}
}
