//
//  FeedlyCollection.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyCollection: Codable, Sendable {

	public let feeds: [FeedlyFeed]
	public let label: String
	public let id: String
}
