//
//  FeedlyGetEntriesService.swift
//  Account
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlyGetEntriesService: AnyObject {
	
	@MainActor func getEntries(for ids: Set<String>) async throws -> [FeedlyEntry]
}
