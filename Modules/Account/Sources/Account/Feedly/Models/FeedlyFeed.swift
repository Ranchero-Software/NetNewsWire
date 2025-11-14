//
//  FeedlyFeed.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated struct FeedlyFeed: Codable, Sendable {
	let id: String
	let title: String?
	let updated: Date?
	let website: String?
}
