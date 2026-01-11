//
//  FeedlyGetCollectionsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyCollectionProviding: AnyObject {
	var collections: [FeedlyCollection] { get }
}

/// Get Collections from Feedly.
final class FeedlyGetCollectionsOperation: FeedlyOperation, FeedlyCollectionProviding, @unchecked Sendable {

	let service: FeedlyGetCollectionsService

	private(set) var collections = [FeedlyCollection]()

	@MainActor init(service: FeedlyGetCollectionsService) {
		self.service = service
		super.init()
	}

	@MainActor override func run() {
		Feedly.logger.debug("FeedlyGetCollectionsOperation: Requesting collections")

		service.getCollections { result in
			Task { @MainActor in
				switch result {
				case .success(let collections):
					Feedly.logger.debug("FeedlyGetCollectionsOperation: Received collections \(collections.map { $0.id })")
					self.collections = collections
					self.didComplete()

				case .failure(let error):
					Feedly.logger.error("FeedlyGetCollectionsOperation: Unable to request collections with error \(error.localizedDescription)")
					self.didComplete(with: error)
				}
			}
		}
	}
}
