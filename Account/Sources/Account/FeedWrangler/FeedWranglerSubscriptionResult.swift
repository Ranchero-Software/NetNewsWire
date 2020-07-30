//
//  FeedWranglerSubscriptionResult.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-11-20.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedWranglerSubscriptionResult: Hashable, Codable {
	
	let feed: FeedWranglerSubscription
	let error: String?
	let result: String
	
}

