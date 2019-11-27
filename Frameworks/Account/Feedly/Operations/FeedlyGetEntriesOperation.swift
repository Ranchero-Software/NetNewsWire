//
//  FeedlyGetEntriesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Single responsibility is to get full entries for the entry identifiers.
final class FeedlyGetEntriesOperation: FeedlyOperation, FeedlyEntryProviding {
	let account: Account
	let service: FeedlyGetEntriesService
	let provider: FeedlyEntryIdenifierProviding
	let log: OSLog
		
	init(account: Account, service: FeedlyGetEntriesService, provider: FeedlyEntryIdenifierProviding, log: OSLog) {
		self.account = account
		self.service = service
		self.provider = provider
		self.log = log
	}
	
	private (set) var entries = [FeedlyEntry]()
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		service.getEntries(for: provider.entryIds) { result in
			switch result {
			case .success(let entries):
				self.entries = entries
				self.didFinish()
				
			case .failure(let error):
				os_log(.debug, log: self.log, "Unable to get entries: %{public}@.", error as NSError)
				self.didFinish(error)
			}
		}
	}
}
