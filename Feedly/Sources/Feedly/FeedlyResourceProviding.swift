//
//  FeedlyResourceProviding.swift
//  Account
//
//  Created by Kiel Gillard on 11/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlyResourceProviding {
	@MainActor var resource: FeedlyResourceID { get }
}

extension FeedlyFeedResourceID: FeedlyResourceProviding {
	
	public var resource: FeedlyResourceID {
		return self
	}
}
