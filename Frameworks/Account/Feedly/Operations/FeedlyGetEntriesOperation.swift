//
//  FeedlyGetEntriesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Single responsibility is to get full entries for the entry identifiers.
final class FeedlyGetEntriesOperation: FeedlyOperation, FeedlyEntryProviding {
	let account: Account
	let service: FeedlyGetEntriesService
	let provider: FeedlyEntryIdenifierProviding
		
	init(account: Account, service: FeedlyGetEntriesService, provider: FeedlyEntryIdenifierProviding) {
		self.account = account
		self.service = service
		self.provider = provider
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
				self.didFinish(error)
			}
		}
	}
}
