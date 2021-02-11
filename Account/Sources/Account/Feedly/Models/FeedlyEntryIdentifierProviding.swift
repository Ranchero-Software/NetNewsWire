//
//  FeedlyEntryIdentifierProviding.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyEntryIdentifierProviding: AnyObject {
	var entryIds: Set<String> { get }
}

final class FeedlyEntryIdentifierProvider: FeedlyEntryIdentifierProviding {
	private (set) var entryIds: Set<String>
	
	init(entryIds: Set<String> = Set()) {
		self.entryIds = entryIds
	}
	
	func addEntryIds(from provider: FeedlyEntryIdentifierProviding) {
		entryIds.formUnion(provider.entryIds)
	}
	
	func addEntryIds(in articleIds: [String]) {
		entryIds.formUnion(articleIds)
	}
}
