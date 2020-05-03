//
//  RedditFeedProvider.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import OAuthSwift
import Secrets
import RSParser

public enum RedditFeedProviderError: LocalizedError {
	case unknown
	
	public var localizedDescription: String {
		switch self {
		case .unknown:
			return NSLocalizedString("An Reddit Twitter Feed Provider error has occurred.", comment: "Unknown error")
		}
	}
}

public struct RedditFeedProvider: FeedProvider {

	private static let server = "api.twitter.com"
	private static let apiBase = "https://api.twitter.com/1.1/"
	private static let dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
	
	private static let userPaths = ["/home", "/notifications"]
	private static let reservedPaths = ["/search", "/explore", "/messages", "/i", "/compose"]
	
	public var username: String
	
	private var oauthToken: String
	private var oauthTokenSecret: String

	private var client: OAuthSwiftClient
	
	public init?(tokenSuccess: OAuthSwift.TokenSuccess) {
		guard let username = tokenSuccess.parameters["screen_name"] as? String else {
				return nil
		}
		
		self.username = username
		self.oauthToken = tokenSuccess.credential.oauthToken
		self.oauthTokenSecret = tokenSuccess.credential.oauthTokenSecret

		let tokenCredentials = Credentials(type: .oauthAccessToken, username: username, secret: oauthToken)
		try? CredentialsManager.storeCredentials(tokenCredentials, server: Self.server)
		
		let tokenSecretCredentials = Credentials(type: .oauthAccessTokenSecret, username: username, secret: oauthTokenSecret)
		try? CredentialsManager.storeCredentials(tokenSecretCredentials, server: Self.server)
		
		client = OAuthSwiftClient(consumerKey: Secrets.twitterConsumerKey,
								  consumerSecret: Secrets.twitterConsumerSecret,
								  oauthToken: oauthToken,
								  oauthTokenSecret: oauthTokenSecret,
								  version: .oauth1)
	}
	
	public init?(username: String) {
		self.username = username
		
		guard let tokenCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessToken, server: Self.server, username: username),
			let tokenSecretCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessTokenSecret, server: Self.server, username: username) else {
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

	public func ability(_ urlComponents: URLComponents) -> FeedProviderAbility {
		guard urlComponents.host?.hasSuffix("reddit.com") ?? false else {
			return .none
		}
		
		if let username = urlComponents.user {
			if username == username {
				return .owner
			} else {
				return .none
			}
		}
		
		return .available
	}

	public func iconURL(_ urlComponents: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		completion(.failure(TwitterFeedProviderError.screenNameNotFound))
	}

	public func assignName(_ urlComponents: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		let path = urlComponents.path
		
		switch path {
		case "", "/":
			let name = NSLocalizedString("Reddit Timeline", comment: "Reddit Timeline")
			completion(.success(name))
		case "/r", "/u":
			let path = String(path.suffix(from: path.index(path.startIndex, offsetBy: 2)))
			completion(.success(path))
		case "/user":
			let path = String(path.suffix(from: path.index(path.startIndex, offsetBy: 5)))
			completion(.success(path))
		default:
			completion(.failure(TwitterFeedProviderError.unknown))
		}
	}
	
	public func refresh(_ webFeed: WebFeed, completion: @escaping (Result<Set<ParsedItem>, Error>) -> Void) {
//		guard let urlComponents = URLComponents(string: webFeed.url) else {
//			completion(.failure(TwitterFeedProviderError.unknown))
//			return
//		}
		
		completion(.success(Set<ParsedItem>()))
	}
	
}

// MARK: OAuth1SwiftProvider

extension RedditFeedProvider: OAuth2SwiftProvider {
	
	public static var oauth2Swift: OAuth2Swift {
		return OAuth2Swift(consumerKey: "", consumerSecret: "", authorizeUrl: "", accessTokenUrl: "", responseType: "")
	}
	
}
