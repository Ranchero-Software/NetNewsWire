//
//  FeedlyFeed.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyFeed: Codable {
	let id: String
	let title: String?
	let updated: Date?
	let website: String?
}
