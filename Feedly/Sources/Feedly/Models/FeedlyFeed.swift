//
//  FeedlyFeed.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyFeed: Codable, Sendable {

	public let id: String
	public let title: String?
	public let updated: Date?
	public let website: String?
}
