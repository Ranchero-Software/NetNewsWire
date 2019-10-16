//
//  FeedWranglerSubscription.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-10-16.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//
import Foundation
import RSCore
import RSParser

struct FeedWranglerSubscription: Hashable, Codable {
	let title: String
	let feed_id: Int
	let feed_url: String
	let site_url: String?
	
}
