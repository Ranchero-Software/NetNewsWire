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
	
	public var userID: String
	public var screenName: String

	public init(tokenSuccess: OAuthSwift.TokenSuccess) {
		// TODO: beef this up
		userID = tokenSuccess.parameters["user_id"] as? String ?? ""
		screenName = tokenSuccess.parameters["screen_name"] as? String ?? ""
		
		//				let token = tokenSuccess.credential.oauthToken
		//				let secret = tokenSuccess.credential.oauthTokenSecret

		// TODO: save credentials here
	}
	
	public init(username: String) {
		self.userID = username
		self.screenName = "Stored Somewhere"
		
		// TODO: load credentials here
	}
	
}

// MARK: FeedProvider

extension TwitterFeedProvider: FeedProvider {
	
}
