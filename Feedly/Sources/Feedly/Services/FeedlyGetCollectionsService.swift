//
//  FeedlyGetCollectionsService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlyGetCollectionsService: AnyObject {
	
	@MainActor func getCollections() async throws -> [FeedlyCollection]
}
