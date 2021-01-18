//
//  File.swift
//  
//
//  Created by Jonathan Bennett on 2021-01-14.
//


import Foundation

struct FeedWranglerFeedItemId: Hashable, Codable {
    
    let feedItemID: Int
    
    enum CodingKeys: String, CodingKey {
        case feedItemID = "feed_item_id"
    }
    
}
