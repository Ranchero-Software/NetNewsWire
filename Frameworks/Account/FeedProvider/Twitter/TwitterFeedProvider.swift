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
	case screenNameNotFound
	case unknown
}

public struct TwitterFeedProvider: FeedProvider {

	private static let server = "api.twitter.com"
	private static let apiBase = "https://api.twitter.com/1.1/"
	
	private static let userPaths = ["/home", "/notifications"]
	private static let reservedPaths = ["/search", "/explore", "/messages", "/i", "/compose"]
	
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
		
		let bestUserName = username != nil ? username : urlComponents.user
		if bestUserName == userID {
			return .owner
		}
		
		return .available
	}

	public func iconURL(_ urlComponents: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		if let screenName = deriveScreenName(urlComponents) {
			fetchUser(screenName: screenName) { result in
				switch result {
				case .success(let user):
					if let avatarURL = user.avatarURL {
						completion(.success(avatarURL))
					} else {
						completion(.failure(TwitterFeedProviderError.screenNameNotFound))
					}
				case .failure(let error):
					completion(.failure(error))
				}
			}
		} else {
			completion(.failure(TwitterFeedProviderError.screenNameNotFound))
		}
	}

	public func assignName(_ urlComponents: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		switch urlComponents.path {
			
		case "/", "/home":
			let name = NSLocalizedString("Twitter Timeline", comment: "Twitter Timeline")
			completion(.success(name))
			
		case "/notifications/mentions":
			let name = NSLocalizedString("Twitter Mentions", comment: "Twitter Mentions")
			completion(.success(name))
			
		case "/search":
			if let query = urlComponents.queryItems?.first(where: { $0.name == "q" })?.value {
				let localized = NSLocalizedString("Twitter Search: %@", comment: "Twitter Search")
				let searchName = NSString.localizedStringWithFormat(localized as NSString, query) as String
				completion(.success(searchName))
			} else {
				let name = NSLocalizedString("Twitter Search", comment: "Twitter Search")
				completion(.success(name))
			}
			
		default:
			if let screenName = deriveScreenName(urlComponents) {
				fetchUser(screenName: screenName) { result in
					switch result {
					case .success(let user):
						if let userName = user.name {
							let localized = NSLocalizedString("%@ on Twitter", comment: "Twitter Name")
							let onName = NSString.localizedStringWithFormat(localized as NSString, userName) as String
							completion(.success(onName))
						} else {
							completion(.failure(TwitterFeedProviderError.screenNameNotFound))
						}
					case .failure(let error):
						completion(.failure(error))
					}
				}
			} else {
				completion(.failure(TwitterFeedProviderError.unknown))
			}
			
		}
	}
	
	public func refresh(_ webFeed: WebFeed, completion: @escaping (Result<Set<ParsedItem>, Error>) -> Void) {
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
	
	func deriveScreenName(_ urlComponents: URLComponents) -> String? {
		let path = urlComponents.path
		guard !Self.reservedPaths.contains(path) else { return nil }
		
		if path.isEmpty || Self.userPaths.contains(path) {
			return screenName
		} else {
			return String(path.suffix(from: path.index(path.startIndex, offsetBy: 1)))
		}
	}
	
	func fetchUser(screenName: String, completion: @escaping (Result<TwitterUser, Error>) -> Void) {
		let url = "\(Self.apiBase)users/show.json"
		let parameters = ["screen_name": screenName]
		
		client.get(url, parameters: parameters) { result in
			switch result {
			case .success(let response):
				let decoder = JSONDecoder()
				do {
					let user = try decoder.decode(TwitterUser.self, from: response.data)
					completion(.success(user))
				} catch {
					completion(.failure(error))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
}
