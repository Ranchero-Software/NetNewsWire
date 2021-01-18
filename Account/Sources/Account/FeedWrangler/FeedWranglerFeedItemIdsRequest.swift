//
//  FeedWranglerFeedItemsRequest.swift
//  Account
//
//  Created by Jonathan Bennett on 2021-01-14.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedWranglerFeedItemIdsRequest: Hashable, Codable {
    
    let count: Int
    let feedItems: [FeedWranglerFeedItemId]
    let error: String?
    let result: String
    
    enum CodingKeys: String, CodingKey {
        case count = "count"
        case feedItems = "feed_items"
        case error = "error"
        case result = "result"
    }
    
}
