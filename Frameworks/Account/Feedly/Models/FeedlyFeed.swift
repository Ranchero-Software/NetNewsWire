//
//  FeedlyFeed.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyFeed: Codable {
	var id: String
	var title: String?
	var updated: Date?
	var website: String?
}
