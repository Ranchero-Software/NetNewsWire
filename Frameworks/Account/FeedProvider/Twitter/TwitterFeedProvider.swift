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
import RSParser

// TODO: Beef up error handling...
public enum TwitterFeedProviderError: Error {
	case unknown
}

public struct TwitterFeedProvider: FeedProvider {

	private static let server = "api.twitter.com"
	private static let apiBase = "https://api.twitter.com/1.1/"
	
	public var userID: String
	public var screenName: String
	
	private var oauthToken: String
	private var oauthTokenSecret: String

	private var client: OAuthSwiftClient
	
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
		
		client = OAuthSwiftClient(consumerKey: Secrets.twitterConsumerKey,
								  consumerSecret: Secrets.twitterConsumerSecret,
								  oauthToken: oauthToken,
								  oauthTokenSecret: oauthTokenSecret,
								  version: .oauth1)
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
		
		client = OAuthSwiftClient(consumerKey: Secrets.twitterConsumerKey,
								  consumerSecret: Secrets.twitterConsumerSecret,
								  oauthToken: oauthToken,
								  oauthTokenSecret: oauthTokenSecret,
								  version: .oauth1)
	}

	public func ability(_ urlComponents: URLComponents, forUsername username: String?) -> FeedProviderAbility {
		guard urlComponents.host?.hasSuffix("twitter.com") ?? false else {
			return .none
		}
		
		if let username = username, username == userID {
			return .owner
		}
		
		return .available
	}

	public func iconURL(_ url: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		let screenName = extractScreenName(url)
		fetchIconURL(screenName: screenName, completion: completion)
	}

	public func provide(_ url: URLComponents, completion: @escaping (Result<ParsedFeed, Error>) -> Void) {
		// TODO: Finish implementation
	}
	
	public func refresh(_ url: URLComponents, completion: @escaping (Result<Set<ParsedItem>, Error>) -> Void) {
		// TODO: Finish implementation
	}

}

// MARK: OAuth1SwiftProvider

extension TwitterFeedProvider: OAuth1SwiftProvider {
	
	public static var oauth1Swift: OAuth1Swift {
		return OAuth1Swift(
			consumerKey: Secrets.twitterConsumerKey,
			consumerSecret: Secrets.twitterConsumerSecret,
			requestTokenUrl: "https://api.twitter.com/oauth/request_token",
			authorizeUrl:    "https://api.twitter.com/oauth/authorize",
			accessTokenUrl:  "https://api.twitter.com/oauth/access_token"
		)
	}
	
}

// MARK: Private

private extension TwitterFeedProvider {
	
	// TODO: Full parsing routine
	func extractScreenName(_ urlComponents: URLComponents) -> String {
		let path = urlComponents.path
		if let index = path.firstIndex(of: "?") {
			let range = path.index(path.startIndex, offsetBy: 1)...index
			return String(path[range])
		} else {
			return String(path.suffix(from: path.index(path.startIndex, offsetBy: 1)))
		}
	}
	
	// TODO: Update to retrieve the full user
	func fetchIconURL(screenName: String, completion: @escaping (Result<String, Error>) -> Void) {
		guard screenName != "search" else {
			completion(.failure(TwitterFeedProviderError.unknown))
			return
		}
		
		let url = "\(Self.apiBase)users/show.json"
		let parameters = ["screen_name": screenName]
		
		client.get(url, parameters: parameters) { result in
			switch result {
			case .success(let response):
				if let json = try? response.jsonObject() as? [String: Any], let url = json["profile_image_url_https"] as? String {
					completion(.success(url))
				} else {
					completion(.failure(TwitterFeedProviderError.unknown))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
}
