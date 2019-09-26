//
//  FeedlyGetStreamParsedItemsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import os.log

protocol FeedlyStreamParsedItemsProviding: class {
	var collection: FeedlyCollection { get }
	var stream: FeedlyStream { get }
	var parsedItems: [ParsedItem] { get }
}

/// Single responsibility is to model articles as ParsedItems for entries in a Collection's stream from Feedly.
final class FeedlyGetStreamParsedItemsOperation: FeedlyOperation, FeedlyStreamParsedItemsProviding {
	private let account: Account
	private let caller: FeedlyAPICaller
	private let collectionStreamProvider: FeedlyCollectionStreamProviding
	private let log: OSLog
	
	var collection: FeedlyCollection {
		return collectionStreamProvider.collection
	}
	
	var stream: FeedlyStream {
		return collectionStreamProvider.stream
	}
	
	private(set) var parsedItems = [ParsedItem]()
	
	init(account: Account, collectionStreamProvider: FeedlyCollectionStreamProviding, caller: FeedlyAPICaller, log: OSLog) {
		self.account = account
		self.caller = caller
		self.collectionStreamProvider = collectionStreamProvider
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else { return }
		
		parsedItems = stream.items.compactMap { entry -> ParsedItem? in
			guard let origin = entry.origin else {
				// Assertion might be too heavy handed here as our understanding of the data quality from Feedly grows.
				print("Entry has no origin and no way for us to figure out which feed it should belong to: \(entry)")
				return nil
			}
			
			// TODO: Sensible values here.
			let parsed = ParsedItem(syncServiceID: entry.id,
									uniqueID: entry.id,
									feedURL: origin.streamId,
									url: nil,
									externalURL: origin.htmlUrl,
									title: entry.title,
									contentHTML: entry.content?.content,
									contentText: nil, // Seems there is no corresponding field in the JSON, so we might have to derive a value.
									summary: nil,
									imageURL: nil,
									bannerImageURL: nil,
									datePublished: entry.published,
									dateModified: entry.updated,
									authors: nil,
									tags: nil,
									attachments: nil)
			return parsed
		}
		
		os_log(.debug, log: log, "Parsed %i items of %i entries for %@", parsedItems.count, stream.items.count, collection.label)
	}
}
