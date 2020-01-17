//
//  FeedlyCollection.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyCollection: Codable {
	let feeds: [FeedlyFeed]
	let label: String
	let id: String
}
