//
//  RedditFeedProvider.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import OAuthSwift
import Secrets
import RSParser
import RSWeb

public enum RedditFeedProviderError: LocalizedError {
	case unknown
	
	public var localizedDescription: String {
		switch self {
		case .unknown:
			return NSLocalizedString("A Reddit Feed Provider error has occurred.", comment: "Unknown error")
		}
	}
}

public final class RedditFeedProvider: FeedProvider {

	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "RedditFeedProvider")

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
	
	public convenience init?(username: String) {
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
		completion(.failure(RedditFeedProviderError.unknown))
	}

	public func assignName(_ urlComponents: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		let path = urlComponents.path

		if path == "" || path == "/" {
			let name = NSLocalizedString("Reddit Timeline", comment: "Reddit Timeline")
			completion(.success(name))
			return
		}
		
		var name = String(path.suffix(from: path.index(after: path.startIndex)))
		if name.last == "/" {
			_ = name.popLast()
		}
		
		completion(.success(name))
	}
	
	public func refresh(_ webFeed: WebFeed, completion: @escaping (Result<Set<ParsedItem>, Error>) -> Void) {
		guard let urlComponents = URLComponents(string: webFeed.url) else {
			completion(.failure(TwitterFeedProviderError.unknown))
			return
		}
		let api = urlComponents.path
		retrieveListing(api: api, parameters: [:]) { result in
			completion(.success(Set<ParsedItem>()))
		}
		
	}
	
	public static func create(tokenSuccess: OAuthSwift.TokenSuccess, completion: @escaping (Result<RedditFeedProvider, Error>) -> Void) {
		let oauthToken = tokenSuccess.credential.oauthToken
		let oauthRefreshToken = tokenSuccess.credential.oauthRefreshToken
		let redditFeedProvider = RedditFeedProvider(oauthToken: oauthToken, oauthRefreshToken: oauthRefreshToken)
		
		redditFeedProvider.retrieveUserName() { result in
			switch result {
			case .success(let username):

				do {
					redditFeedProvider.username = username
					try storeCredentials(username: username, oauthToken: oauthToken, oauthRefreshToken: oauthRefreshToken)
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
		let scope = "identity mysubreddits read"
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
	
	func retrieveListing(api: String, parameters: [String: Any], completion: @escaping (Result<RedditListing, Error>) -> Void) {
		guard let client = client else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		let url = "\(Self.apiBase)\(api).json"

		var expandedParameters = parameters
		expandedParameters["raw_json"] = "1"

		client.get(url, parameters: expandedParameters, headers: Self.userAgentHeaders) { result in
			switch result {
			case .success(let response):
				
				let jsonString = String(data: response.data, encoding: .utf8)
				let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("reddit.json")
				print("******** writing to: \(url.path)")
				try? jsonString?.write(toFile: url.path, atomically: true, encoding: .utf8)

//				let decoder = JSONDecoder()
//				let dateFormatter = DateFormatter()
//				dateFormatter.dateFormat = Self.dateFormat
//				decoder.dateDecodingStrategy = .formatted(dateFormatter)
				
//				do {
//					let listing = try decoder.decode(RedditListing.self, from: response.data)
//					completion(.success(listing))
//				} catch {
//					completion(.failure(error))
//				}
			
				let listing = RedditListing(name: "")
				completion(.success(listing))
				
			case .failure(let oathError):
				self.handleFailure(error: oathError) { error in
					if let error = error {
						completion(.failure(error))
					} else {
						self.retrieveListing(api: api, parameters: parameters, completion: completion)
					}
				}
			}
		}
	}
	
//	func makeParsedItems(_ webFeedURL: String, _ statuses: [TwitterStatus]) -> Set<ParsedItem> {
//		var parsedItems = Set<ParsedItem>()
//
//		for status in statuses {
//			guard let idStr = status.idStr, let statusURL = status.url else { continue }
//
//			let parsedItem = ParsedItem(syncServiceID: nil,
//							  uniqueID: idStr,
//							  feedURL: webFeedURL,
//							  url: statusURL,
//							  externalURL: nil,
//							  title: nil,
//							  language: nil,
//							  contentHTML: status.renderAsHTML(),
//							  contentText: status.renderAsText(),
//							  summary: nil,
//							  imageURL: nil,
//							  bannerImageURL: nil,
//							  datePublished: status.createdAt,
//							  dateModified: nil,
//							  authors: makeParsedAuthors(status.user),
//							  tags: nil,
//							  attachments: nil)
//			parsedItems.insert(parsedItem)
//		}
//
//		return parsedItems
//	}
//
//	func makeUserURL(_ screenName: String) -> String {
//		return "https://twitter.com/\(screenName)"
//	}
//
//	func makeParsedAuthors(_ user: TwitterUser?) -> Set<ParsedAuthor>? {
//		guard let user = user else { return nil }
//		return Set([ParsedAuthor(name: user.name, url: user.url, avatarURL: user.avatarURL, emailAddress: nil)])
//	}
	
    func handleFailure(error: OAuthSwiftError, completion: @escaping (Error?) -> Void) {
		if case .tokenExpired = error {
			os_log(.debug, log: self.log, "Access token expired, attempting to renew...")

			oauthSwift?.renewAccessToken(withRefreshToken: oauthRefreshToken) { [weak self] result in
				guard let self = self, let username = self.username else {
					completion(nil)
					return
				}
				
				switch result {
				case .success(let tokenSuccess):
					self.oauthToken = tokenSuccess.credential.oauthToken
					self.oauthRefreshToken = tokenSuccess.credential.oauthRefreshToken
					do {
						try Self.storeCredentials(username: username, oauthToken: self.oauthToken, oauthRefreshToken: self.oauthRefreshToken)
						os_log(.debug, log: self.log, "Access token renewed.")
					} catch {
						completion(error)
						return
					}
					completion(nil)
				case .failure(let oathError):
					completion(oathError)
				}
			}
			
		} else {
			completion(error)
		}
    }
	
	static func storeCredentials(username: String, oauthToken: String, oauthRefreshToken: String) throws {
		let tokenCredentials = Credentials(type: .oauthAccessToken, username: username, secret: oauthToken)
		try CredentialsManager.storeCredentials(tokenCredentials, server: Self.server)
		let tokenSecretCredentials = Credentials(type: .oauthRefreshToken, username: username, secret: oauthRefreshToken)
		try CredentialsManager.storeCredentials(tokenSecretCredentials, server: Self.server)
	}
}
