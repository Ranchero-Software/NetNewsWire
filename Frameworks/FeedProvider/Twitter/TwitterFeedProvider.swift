//
//  TwitterFeedProvider.swift
//  FeedProvider
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Secrets
import OAuthSwift

public struct TwitterFeedProvider {
	
	public var username: String
	
	public init(username: String) {
		self.username = username
	}
	
}

// MARK: FeedProvider

extension TwitterFeedProvider: FeedProvider {
	
}
