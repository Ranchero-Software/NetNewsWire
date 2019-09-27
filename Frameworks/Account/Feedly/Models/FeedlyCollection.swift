//
//  FeedlyCollection.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyCollection: Codable {
	var feeds: [FeedlyFeed]
	var label: String
	var id: String
}
