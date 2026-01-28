//
//  FeedlyOrganiseParsedItemsByFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import os.log

protocol FeedlyParsedItemsByFeedProviding {
	var parsedItemsByFeedProviderName: String { get }
	var parsedItemsKeyedByFeedId: [String: Set<ParsedItem>] { get }
}

/// Group articles by their feeds.
final class FeedlyOrganiseParsedItemsByFeedOperation: FeedlyOperation, FeedlyParsedItemsByFeedProviding {

	private let account: Account
	private let parsedItemProvider: FeedlyParsedItemProviding

	var parsedItemsByFeedProviderName: String {
		return name ?? String(describing: Self.self)
	}

	var parsedItemsKeyedByFeedId: [String : Set<ParsedItem>] {
		precondition(Thread.isMainThread) // Needs to be on main thread because Feed is a main-thread-only model type.
		return itemsKeyedByFeedId
	}

	private var itemsKeyedByFeedId = [String: Set<ParsedItem>]()

	init(account: Account, parsedItemProvider: FeedlyParsedItemProviding) {
		self.account = account
		self.parsedItemProvider = parsedItemProvider
	}

	override func run() {
		defer {
			didFinish()
		}

		let items = parsedItemProvider.parsedEntries
		var dict = [String: Set<ParsedItem>](minimumCapacity: items.count)

		for item in items {
			let key = item.feedURL
			let value: Set<ParsedItem> = {
				if var items = dict[key] {
					items.insert(item)
					return items
				} else {
					return [item]
				}
			}()
			dict[key] = value
		}

		Feedly.logger.info("Feedly: Grouped \(items.count) items by \(dict.count) feeds for \(self.parsedItemProvider.parsedItemProviderName)")

		itemsKeyedByFeedId = dict
	}
}
