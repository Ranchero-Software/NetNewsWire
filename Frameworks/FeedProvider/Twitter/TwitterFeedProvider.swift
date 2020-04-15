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
	
	private static let server = "api.twitter.com"
	
	public var userID: String
	public var screenName: String
	
	private var oauthToken: String
	private var oauthTokenSecret: String

	public init?(tokenSuccess: OAuthSwift.TokenSuccess) {
		guard let userID = tokenSuccess.parameters["user_id"] as? String,
			let screenName = tokenSuccess.parameters["screen_name"] as? String else {
				return nil
		}
		
		self.userID = userID
		self.screenName = screenName
		self.oauthToken = tokenSuccess.credential.oauthToken
		self.oauthTokenSecret = tokenSuccess.credential.oauthTokenSecret

		let tokenCredentials = Credentials(type: .oauthAccessToken, username: userID, secret: oauthToken)
		try? CredentialsManager.storeCredentials(tokenCredentials, server: Self.server)
		
		let tokenSecretCredentials = Credentials(type: .oauthAccessTokenSecret, username: userID, secret: oauthTokenSecret)
		try? CredentialsManager.storeCredentials(tokenSecretCredentials, server: Self.server)
	}
	
	public init?(userID: String, screenName: String) {
		self.userID = userID
		self.screenName = screenName
		
		guard let tokenCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessToken, server: Self.server, username: userID),
			let tokenSecretCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessTokenSecret, server: Self.server, username: userID) else {
				return nil
		}

		self.oauthToken = tokenCredentials.secret
		self.oauthTokenSecret = tokenSecretCredentials.secret
	}
	
}

// MARK: FeedProvider

extension TwitterFeedProvider: FeedProvider {
	
}
