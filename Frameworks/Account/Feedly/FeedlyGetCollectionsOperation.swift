//
//  FeedlyGetCollectionsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyCollectionProviding: class {
	var collections: [FeedlyCollection] { get }
}

/// Single responsibility is to get Collections from Feedly.
final class FeedlyGetCollectionsOperation: FeedlySyncOperation, FeedlyCollectionProviding {
	
	let caller: FeedlyAPICaller
	
	private(set) var collections = [FeedlyCollection]()
	
	init(caller: FeedlyAPICaller) {
		self.caller = caller
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		caller.getCollections { result in
			switch result {
			case .success(let collections):
				self.collections = collections
				self.didFinish()
				
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
}
