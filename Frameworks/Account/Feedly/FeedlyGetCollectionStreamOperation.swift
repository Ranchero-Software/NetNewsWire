//
//  FeedlyGetCollectionStreamOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyCollectionStreamProviding: class {
	var collection: FeedlyCollection { get }
	var stream: FeedlyStream { get }
}

/// Single responsibility is to get the stream content of a Collection from Feedly.
final class FeedlyGetCollectionStreamOperation: FeedlySyncOperation, FeedlyCollectionStreamProviding {
	
	private(set) var collection: FeedlyCollection
	
	var stream: FeedlyStream {
		guard let stream = storedStream else {
			// TODO: this is probably more error prone than it seems!
			fatalError("\(type(of: self)) has been told to finish too early or a dependency is ignoring cancellation.")
		}
		return stream
	}
	
	private var storedStream: FeedlyStream?
	
	let account: Account
	let caller: FeedlyAPICaller
	
	init(account: Account, collection: FeedlyCollection, caller: FeedlyAPICaller) {
		self.account = account
		self.collection = collection
		self.caller = caller
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		//TODO: Use account metadata to get articles newer than some date.
		caller.getStream(for: collection) { result in
			switch result {
			case .success(let stream):
				self.storedStream = stream
				self.didFinish()
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
}
