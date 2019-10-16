//
//  FeedlySyncStarredArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser

final class FeedlySyncStarredArticlesOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyGetStreamOperationDelegate {
	private let account: Account
	private let operationQueue: OperationQueue
	private let caller: FeedlyAPICaller
	private let log: OSLog
	
	private let setStatuses: FeedlySetStarredArticlesOperation
	
	/// Buffers every starred/saved entry from every page.
	private class StarredEntryProvider: FeedlyEntryProviding {
		var resource: FeedlyResourceId
		
		private(set) var parsedEntries = Set<ParsedItem>()
		private(set) var entries = [FeedlyEntry]()
		
		init(resource: FeedlyResourceId) {
			self.resource = resource
		}
		
		func addEntries(from provider: FeedlyEntryProviding) {
			entries.append(contentsOf: provider.entries)
			parsedEntries.formUnion(provider.parsedEntries)
		}
	}
	
	private let entryProvider: StarredEntryProvider
	
	init(account: Account, credentials: Credentials, caller: FeedlyAPICaller, log: OSLog) {
		self.account = account
		self.caller = caller
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		self.log = log
				
		let saved = FeedlyTagResourceId.saved(for: credentials.username)
		let provider = StarredEntryProvider(resource: saved)
		self.entryProvider = provider
		self.setStatuses = FeedlySetStarredArticlesOperation(account: account,
															 allStarredEntriesProvider: provider,
															 log: log)
		
		super.init()
		
		let getFirstPage = FeedlyGetStreamOperation(account: account,
													resource: saved,
													caller: caller,
													newerThan: nil)
		
		let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																	  entryProvider: provider,
																	  log: log)

		let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
																	   organisedItemsProvider: organiseByFeed,
																	   log: log)
		
		getFirstPage.delegate = self
		getFirstPage.streamDelegate = self
		
		setStatuses.addDependency(getFirstPage)
		setStatuses.delegate = self
		
		organiseByFeed.addDependency(setStatuses)
		organiseByFeed.delegate = self
		
		updateAccount.addDependency(organiseByFeed)
		updateAccount.delegate = self
		
		let finishOperation = BlockOperation { [weak self] in
			DispatchQueue.main.async {
				self?.didFinish()
			}
		}
		
		finishOperation.addDependency(updateAccount)
		
		let operations = [getFirstPage, setStatuses, organiseByFeed, updateAccount, finishOperation]
		operationQueue.addOperations(operations, waitUntilFinished: false)
	}
	
	override func cancel() {
		operationQueue.cancelAllOperations()
		super.cancel()
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		operationQueue.isSuspended = false
	}
	
	func feedlyGetStreamOperation(_ operation: FeedlyGetStreamOperation, didGet stream: FeedlyStream) {
		entryProvider.addEntries(from: operation)
		os_log(.debug, log: log, "Collecting %i items from %@", stream.items.count, stream.id)
		
		guard let continuation = stream.continuation else {
			return
		}
		
		let nextPageOperation = FeedlyGetStreamOperation(account: operation.account,
														 resource: operation.resource,
														 caller: operation.caller,
														 continuation: continuation,
														 newerThan: operation.newerThan)
		nextPageOperation.delegate = self
		nextPageOperation.streamDelegate = self
		
		setStatuses.addDependency(nextPageOperation)
		operationQueue.addOperation(nextPageOperation)
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		operationQueue.cancelAllOperations()
		didFinish(error)
	}
}
