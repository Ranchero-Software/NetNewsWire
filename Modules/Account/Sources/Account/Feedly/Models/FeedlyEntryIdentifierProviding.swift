//
//  FeedlyEntryIdentifierProviding.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyEntryIdentifierProviding: AnyObject {
	var entryIDs: Set<String> { get }
}

final class FeedlyEntryIdentifierProvider: FeedlyEntryIdentifierProviding {
	private(set) var entryIDs: Set<String>

	init(entryIDs: Set<String> = Set()) {
		self.entryIDs = entryIDs
	}

	func addEntryIDs(from provider: FeedlyEntryIdentifierProviding) {
		entryIDs.formUnion(provider.entryIDs)
	}

	func addEntryIDs(in articleIDs: [String]) {
		entryIDs.formUnion(articleIDs)
	}
}
