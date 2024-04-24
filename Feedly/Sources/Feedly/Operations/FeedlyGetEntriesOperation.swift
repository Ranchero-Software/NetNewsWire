//
//  FeedlyGetEntriesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Parser

/// Get full entries for the entry identifiers.
public final class FeedlyGetEntriesOperation: FeedlyOperation, FeedlyEntryProviding, FeedlyParsedItemProviding {

	let service: FeedlyGetEntriesService
	let provider: FeedlyEntryIdentifierProviding
	let log: OSLog

	public init(service: FeedlyGetEntriesService, provider: FeedlyEntryIdentifierProviding, log: OSLog) {
		self.service = service
		self.provider = provider
		self.log = log
	}
	
	private (set) public var entries = [FeedlyEntry]()

	private var storedParsedEntries: Set<ParsedItem>?
	
	public var parsedEntries: Set<ParsedItem> {
		if let entries = storedParsedEntries {
			return entries
		}
		
		let parsed = Set(entries.compactMap {
			FeedlyEntryParser(entry: $0).parsedItemRepresentation
		})
		
		// TODO: Fix the below. There’s an error on the os.log line: "Expression type '()' is ambiguous without more context"
//		if parsed.count != entries.count {
//			let entryIDs = Set(entries.map { $0.id })
//			let parsedIDs = Set(parsed.map { $0.uniqueID })
//			let difference = entryIDs.subtracting(parsedIDs)
//			os_log(.debug, log: log, "%{public}@ dropping articles with ids: %{public}@.", self, difference)
//		}
		
		storedParsedEntries = parsed
		
		return parsed
	}
	
	public var parsedItemProviderName: String {
		return name ?? String(describing: Self.self)
	}
	
	public override func run() {

		Task { @MainActor in

			do {
				let entries = try await service.getEntries(for: provider.entryIDs)
				self.entries = entries
				self.didFinish()
			} catch {
				os_log(.debug, log: self.log, "Unable to get entries: %{public}@.", error as NSError)
				self.didFinish(with: error)
			}
		}
	}
}
