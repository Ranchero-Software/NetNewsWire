//
//  FeedlyGetCollectionsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

protocol FeedlyCollectionProviding: AnyObject {
	var collections: [FeedlyCollection] { get }
}

/// Get Collections from Feedly.
final class FeedlyGetCollectionsOperation: FeedlyOperation, FeedlyCollectionProviding, Logging {
	
	let service: FeedlyGetCollectionsService
	
	private(set) var collections = [FeedlyCollection]()

	init(service: FeedlyGetCollectionsService) {
		self.service = service
	}
	
	override func run() {
        logger.debug("Requesting collections.")
		
		service.getCollections { result in
			switch result {
			case .success(let collections):
                self.logger.debug("Receving collections: \(collections.map({ $0.id }))")
				self.collections = collections
				self.didFinish()
				
			case .failure(let error):
                self.logger.error("Unable to request collections: \(error.localizedDescription, privacy: .public).")
				self.didFinish(with: error)
			}
		}
	}
}
