//
//  FeedlyResourceProviding.swift
//  Account
//
//  Created by Kiel Gillard on 11/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyResourceProviding {
	var resource: FeedlyResourceId { get }
}

extension FeedlyFeedResourceId: FeedlyResourceProviding {
	
	var resource: FeedlyResourceId {
		return self
	}
}
