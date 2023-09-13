//
//  FeedlyGetUpdatedArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Secrets

/// Single responsibility is to identify articles that have changed since a particular date.
///
/// Typically, it pages through the article ids of the global.all stream.
/// When all the article ids are collected, it is the responsibility of another operation to download them when appropriate.
class FeedlyGetUpdatedArticleIdsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, Logging {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIDsService
	private let newerThan: Date?
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIDsService, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.newerThan = newerThan
	}
	
	convenience init(account: Account, userId: String, service: FeedlyGetStreamIDsService, newerThan: Date?) {
		let all = FeedlyCategoryResourceID.Global.all(for: userId)
		self.init(account: account, resource: all, service: service, newerThan: newerThan)
	}
	
	var entryIDs: Set<String> {
		return storedUpdatedArticleIds
	}
	
	private var storedUpdatedArticleIds = Set<String>()
	
	override func run() {
		getStreamIds(nil)
	}
	
	private func getStreamIds(_ continuation: String?) {
		guard let date = newerThan else {
            logger.debug("No date provided so everything must be new (nothing is updated).")
			didFinish()
			return
		}
		
		service.streamIDs(for: resource, continuation: continuation, newerThan: date, unreadOnly: nil, completion: didGetStreamIds(_:))
	}
	
	private func didGetStreamIds(_ result: Result<FeedlyStreamIDs, Error>) {
		guard !isCanceled else {
			didFinish()
			return
		}
		
		switch result {
		case .success(let streamIds):
			storedUpdatedArticleIds.formUnion(streamIds.ids)
			
			guard let continuation = streamIds.continuation else {
                self.logger.debug("\(self.storedUpdatedArticleIds.count, privacy: .public) articles updated since last successful sync start date.")
				didFinish()
				return
			}
			
			getStreamIds(continuation)
			
		case .failure(let error):
            self.logger.error("Error getting FeedlyStreamIDs: \(error.localizedDescription, privacy: .public).")
			didFinish(with: error)
		}
	}
}
