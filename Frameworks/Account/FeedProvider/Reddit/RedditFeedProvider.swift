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
import RSWeb

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

	private static let server = "www.reddit.com"
	private static let apiBase = "https://oauth.reddit.com"
	private static let userAgentHeaders = UserAgent.headers() as! [String: String]
	
	private static let userPaths = ["/home", "/notifications"]
	private static let reservedPaths = ["/search", "/explore", "/messages", "/i", "/compose"]
	
	public var username: String?
	
	private var oauthToken: String
	private var oauthRefreshToken: String

    private var oauthSwift: OAuth2Swift?
	private var client: OAuthSwiftClient? {
		return oauthSwift?.client
	}
	
	public init?(username: String) {
		guard let tokenCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessToken, server: Self.server, username: username),
			let refreshTokenCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthRefreshToken, server: Self.server, username: username) else {
				return nil
		}

		self.init(oauthToken: tokenCredentials.secret, oauthRefreshToken: refreshTokenCredentials.secret)
		self.username = username
	}

	init(oauthToken: String, oauthRefreshToken: String) {
		self.oauthToken = oauthToken
		self.oauthRefreshToken = oauthRefreshToken
		oauthSwift = Self.oauth2Swift
		oauthSwift!.client.credential.oauthToken = oauthToken
		oauthSwift!.client.credential.oauthRefreshToken = oauthRefreshToken
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
	
	public static func create(tokenSuccess: OAuthSwift.TokenSuccess, completion: @escaping (Result<RedditFeedProvider, Error>) -> Void) {
		let oauthToken = tokenSuccess.credential.oauthToken
		let oauthRefreshToken = tokenSuccess.credential.oauthRefreshToken
		var redditFeedProvider = RedditFeedProvider(oauthToken: oauthToken, oauthRefreshToken: oauthRefreshToken)
		
		redditFeedProvider.retrieveUserName() { result in
			switch result {
			case .success(let username):

				do {
					let tokenCredentials = Credentials(type: .oauthAccessToken, username: username, secret: oauthToken)
					try CredentialsManager.storeCredentials(tokenCredentials, server: Self.server)
					let tokenSecretCredentials = Credentials(type: .oauthRefreshToken, username: username, secret: oauthRefreshToken)
					try CredentialsManager.storeCredentials(tokenSecretCredentials, server: Self.server)

					redditFeedProvider.username = username
					completion(.success(redditFeedProvider))
				} catch {
					completion(.failure(error))
				}

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	

}

// MARK: OAuth1SwiftProvider

extension RedditFeedProvider: OAuth2SwiftProvider {
	
	public static var oauth2Swift: OAuth2Swift {
		let oauth2 = OAuth2Swift(consumerKey: Secrets.redditConsumerKey,
								 consumerSecret: "",
								 authorizeUrl: "https://www.reddit.com/api/v1/authorize.compact?",
								 accessTokenUrl: "https://www.reddit.com/api/v1/access_token",
								 responseType: "token")
		oauth2.accessTokenBasicAuthentification = true
		return oauth2
	}
	
	public static var callbackURL: URL {
		return URL(string: "netnewswire://success")!
	}
	
	public static var oauth2Vars: (state: String, scope: String, params: [String : String]) {
        let state = generateState(withLength: 20)
		let scope = "identity mysubreddits"
        let params = [
			"client_id" : Secrets.redditConsumerKey,
            "response_type" : "code",
            "state" : state,
            "redirect_uri" : "netnewswire://success",
            "duration" : "permanent",
			"scope" : scope
        ]
		return (state: state, scope: scope, params: params)
	}
	
}

private extension RedditFeedProvider {
	
	func retrieveUserName(completion: @escaping (Result<String, Error>) -> Void) {
		guard let client = client else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		client.request(Self.apiBase + "/api/v1/me", method: .GET, headers: Self.userAgentHeaders) { result in
			switch result {
			case .success(let response):
				if let redditUser = try? JSONDecoder().decode(RedditUser.self, from: response.data), let username = redditUser.name {
					completion(.success(username))
				} else {
					completion(.failure(RedditFeedProviderError.unknown))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
		
}
