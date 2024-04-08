//
//  FeedlyEntryIdentifierProviding.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlyEntryIdentifierProviding: AnyObject {
	@MainActor var entryIDs: Set<String> { get }
}

public final class FeedlyEntryIdentifierProvider: FeedlyEntryIdentifierProviding {

	private (set) public var entryIDs: Set<String>

	public init(entryIDs: Set<String> = Set()) {
		self.entryIDs = entryIDs
	}
	
	@MainActor public func addEntryIDs(from provider: FeedlyEntryIdentifierProviding) {
		entryIDs.formUnion(provider.entryIDs)
	}
	
	@MainActor public func addEntryIDs(in articleIDs: [String]) {
		entryIDs.formUnion(articleIDs)
	}
}
