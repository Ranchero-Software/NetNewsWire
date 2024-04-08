//
//  FeedlyFeedsSearchResponse.swift
//  Account
//
//  Created by Kiel Gillard on 1/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyFeedsSearchResponse: Decodable, Sendable {

	public struct Feed: Decodable, Sendable {

		public let title: String
		public let feedId: String
	}
	
	public let results: [Feed]
}
