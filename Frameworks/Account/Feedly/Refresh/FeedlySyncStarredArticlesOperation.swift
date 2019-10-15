//
//  FeedlySyncStarredArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlySyncStarredArticlesOperation: FeedlyOperation {
	private let account: Account
	private let operationQueue: OperationQueue
	private let caller: FeedlyAPICaller
	private let log: OSLog
	
	init(account: Account, caller: FeedlyAPICaller, log: OSLog) {
		self.account = account
		self.caller = caller
		self.operationQueue = OperationQueue()
		self.log = log
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
		
		guard let user = caller.credentials?.username else {
			didFinish(FeedlyAccountDelegateError.notLoggedIn)
			return
		}
		
		class Delegate: FeedlyOperationDelegate {
			var error: Error?
			weak var compoundOperation: FeedlyCompoundOperation?
			
			func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
				compoundOperation?.cancel()
				self.error = error
			}
		}
		
		let delegate = Delegate()
		
		let syncSaved = FeedlyCompoundOperation {

			let saved = FeedlyTagResourceId.saved(for: user)
			os_log(.debug, log: log, "Getting starred articles from \"%@\".", saved.id)
			
			let getSavedStream = FeedlyGetStreamOperation(account: account,
														  resource: saved,
														  caller: caller,
														  newerThan: nil)
			getSavedStream.delegate = delegate
			
			// set statuses
			let setStatuses = FeedlySetStarredArticlesOperation(account: account,
																allStarredEntriesProvider: getSavedStream,
																log: log)
			setStatuses.delegate = delegate
			setStatuses.addDependency(getSavedStream)

			// ingest articles
			let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																		  entryProvider: getSavedStream,
																		  log: log)
			organiseByFeed.delegate = delegate
			organiseByFeed.addDependency(setStatuses)

			let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
																		   organisedItemsProvider: organiseByFeed,
																		   log: log)
			updateAccount.delegate = delegate
			updateAccount.addDependency(organiseByFeed)

			return [getSavedStream, setStatuses, organiseByFeed, updateAccount]
		}
		
		delegate.compoundOperation = syncSaved
		
		let finalOperation = BlockOperation { [weak self] in
			guard let self = self else {
				return
			}
			if let error = delegate.error {
				self.didFinish(error)
			} else {
				self.didFinish()
			}
			os_log(.debug, log: self.log, "Done syncing starred articles.")
		}
		
		finalOperation.addDependency(syncSaved)
		operationQueue.addOperations([syncSaved, finalOperation], waitUntilFinished: false)
	}
	
}
