//
//  FeedlyGetStreamIDsService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlyGetStreamIDsService: AnyObject {

	@MainActor func getStreamIDs(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStreamIDs
}
