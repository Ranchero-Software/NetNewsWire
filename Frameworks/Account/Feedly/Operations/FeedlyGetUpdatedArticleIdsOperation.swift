//
//  FeedlyGetUpdatedArticleIdsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Single responsibility is to identify articles that have changed since a particular date.
///
/// Typically, it pages through the article ids of the global.all stream.
/// When all the article ids are collected, it is the responsibility of another operation to download them when appropriate.
class FeedlyGetUpdatedArticleIdsOperation: FeedlyOperation, FeedlyEntryIdentifierProviding {

	private let account: Account
	private let resource: FeedlyResourceId
	private let service: FeedlyGetStreamIdsService
	private let newerThan: Date?
	private let log: OSLog
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.newerThan = newerThan
		self.log = log
	}
	
	convenience init(account: Account, userId: String, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		let all = FeedlyCategoryResourceId.Global.all(for: userId)
		self.init(account: account, resource: all, service: service, newerThan: newerThan, log: log)
	}
	
	var entryIds: Set<String> {
		return storedUpdatedArticleIds
	}
	
	private var storedUpdatedArticleIds = Set<String>()
	
	override func run() {
		getStreamIds(nil)
	}
	
	private func getStreamIds(_ continuation: String?) {
		guard let date = newerThan else {
			os_log(.debug, log: log, "No date provided so everything must be new (nothing is updated).")
			didFinish()
			return
		}
		
		service.getStreamIds(for: resource, continuation: continuation, newerThan: date, unreadOnly: nil, completion: didGetStreamIds(_:))
	}
	
	private func didGetStreamIds(_ result: Result<FeedlyStreamIds, Error>) {
		guard !isCanceled else {
			didFinish()
			return
		}
		
		switch result {
		case .success(let streamIds):
			storedUpdatedArticleIds.formUnion(streamIds.ids)
			
			guard let continuation = streamIds.continuation else {
				os_log(.debug, log: log, "%{public}i articles updated since last successful sync start date.", storedUpdatedArticleIds.count)
				didFinish()
				return
			}
			
			getStreamIds(continuation)
			
		case .failure(let error):
			didFinish(with: error)
		}
	}
}
