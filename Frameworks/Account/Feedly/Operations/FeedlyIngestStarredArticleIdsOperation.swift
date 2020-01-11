//
//  FeedlyIngestStarredArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Single responsibility is to clone locally the remote starred article state.
///
/// Typically, it pages through the article ids of the global.saved stream.
/// When all the article ids are collected, a status is created for each.
/// The article ids previously marked as starred but not collected become unstarred.
/// So this operation has side effects *for the entire account* it operates on.
final class FeedlyIngestStarredArticleIdsOperation: FeedlyOperation {
	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let entryIdsProvider: FeedlyEntryIdentifierProvider
	private let log: OSLog
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		let resource = FeedlyTagResourceId.Global.saved(for: credentials.username)
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
		service.getStreamIds(for: resource, continuation: continuation, newerThan: nil, unreadOnly: nil, completion: didGetStreamIds(_:))
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
				updateStarredStatuses()
				return
			}
			
			getStreamIds(continuation)
			
		case .failure(let error):
			didFinish(error)
		}
	}
	
	private func updateStarredStatuses() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		account.fetchStarredArticleIDs { result in
			switch result {
			case .success(let localStarredArticleIDs):
				self.processStarredArticleIDs(localStarredArticleIDs)
				
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
	
	func processStarredArticleIDs(_ localStarredArticleIDs: Set<String>) {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		let remoteStarredArticleIDs = entryIdsProvider.entryIds
		
		let group = DispatchGroup()
		
		final class StarredStatusResults {
			var markAsStarredError: Error?
			var markAsUnstarredError: Error?
		}
		
		let results = StarredStatusResults()
		
		group.enter()
		account.markAsStarred(remoteStarredArticleIDs) { error in
			results.markAsStarredError = error
			group.leave()
		}

		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
		group.enter()
		account.markAsUnstarred(deltaUnstarredArticleIDs) { error in
			results.markAsUnstarredError = error
			group.leave()
		}

		group.notify(queue: .main) {
			let markingError = results.markAsStarredError ?? results.markAsUnstarredError
			guard let error = markingError else {
				self.didFinish()
				return
			}
			self.didFinish(error)
		}
	}
}
