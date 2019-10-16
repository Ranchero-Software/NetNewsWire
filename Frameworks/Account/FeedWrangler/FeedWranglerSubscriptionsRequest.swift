//
//  FeedWranglerSubscriptionsRequest.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-10-16.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedWranglerSubscriptionsRequest: Hashable, Codable {
	
	let feeds: [FeedWranglerSubscription]
	let error: String?
	let result: String
	
}
