//
//  FeedlyGetCollectionsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyCollectionProviding: class {
	var collections: [FeedlyCollection] { get }
}

/// Single responsibility is to get Collections from Feedly.
final class FeedlyGetCollectionsOperation: FeedlyOperation, FeedlyCollectionProviding {
	
	let caller: FeedlyAPICaller
	let log: OSLog
	
	private(set) var collections = [FeedlyCollection]()
	
	init(caller: FeedlyAPICaller, log: OSLog) {
		self.caller = caller
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		os_log(.debug, log: log, "Requesting collections.")
		
		caller.getCollections { result in
			switch result {
			case .success(let collections):
				os_log(.debug, log: self.log, "Received collections: %@.", collections.map { $0.id })
				self.collections = collections
				self.didFinish()
				
			case .failure(let error):
				os_log(.debug, log: self.log, "Unable to request collections %@.", error as NSError)
				self.didFinish(error)
			}
		}
	}
}
