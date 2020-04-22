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

public enum TwitterFeedProviderError: LocalizedError {
	case screenNameNotFound
	case unknown
	
	public var localizedDescription: String {
		switch self {
		case .screenNameNotFound:
			return NSLocalizedString("Unable to determine screen name.", comment: "Screen name")
		case .unknown:
			return NSLocalizedString("An unknown Twitter Feed Provider error has occurred.", comment: "Screen name")
		}
	}
}

public enum TwitterFeedType: Int {
	case homeTimeline = 0
	case mentions = 1
	case screenName = 2
	case search = 3
}

public struct TwitterFeedProvider: FeedProvider {

	private static let server = "api.twitter.com"
	private static let apiBase = "https://api.twitter.com/1.1/"
	private static let dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
	
	private static let userPaths = ["/home", "/notifications"]
	private static let reservedPaths = ["/search", "/explore", "/messages", "/i", "/compose"]
	
	public var screenName: String
	
	private var oauthToken: String
	private var oauthTokenSecret: String

	private var client: OAuthSwiftClient
	
	public init?(tokenSuccess: OAuthSwift.TokenSuccess) {
		guard let screenName = tokenSuccess.parameters["screen_name"] as? String else {
				return nil
		}
		
		self.screenName = screenName
		self.oauthToken = tokenSuccess.credential.oauthToken
		self.oauthTokenSecret = tokenSuccess.credential.oauthTokenSecret

		let tokenCredentials = Credentials(type: .oauthAccessToken, username: screenName, secret: oauthToken)
		try? CredentialsManager.storeCredentials(tokenCredentials, server: Self.server)
		
		let tokenSecretCredentials = Credentials(type: .oauthAccessTokenSecret, username: screenName, secret: oauthTokenSecret)
		try? CredentialsManager.storeCredentials(tokenSecretCredentials, server: Self.server)
		
		client = OAuthSwiftClient(consumerKey: Secrets.twitterConsumerKey,
								  consumerSecret: Secrets.twitterConsumerSecret,
								  oauthToken: oauthToken,
								  oauthTokenSecret: oauthTokenSecret,
								  version: .oauth1)
	}
	
	public init?(screenName: String) {
		self.screenName = screenName
		
		guard let tokenCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessToken, server: Self.server, username: screenName),
			let tokenSecretCredentials = try? CredentialsManager.retrieveCredentials(type: .oauthAccessTokenSecret, server: Self.server, username: screenName) else {
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
		
		if let username = username {
			if username == screenName {
				return .owner
			} else {
				return .none
			}
		}
		
		if let user = urlComponents.user, user == screenName {
			return .owner
		}
		
		return .available
	}

	public func iconURL(_ urlComponents: URLComponents, completion: @escaping (Result<String, Error>) -> Void) {
		if let screenName = deriveScreenName(urlComponents) {
			retrieveUser(screenName: screenName) { result in
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
			
		case "", "/", "/home":
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
			if let hashtag = deriveHashtag(urlComponents) {
				completion(.success("#\(hashtag)"))
			} else if let screenName = deriveScreenName(urlComponents) {
				retrieveUser(screenName: screenName) { result in
					switch result {
					case .success(let user):
						if let userName = user.name {
							completion(.success(userName))
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
		guard let urlComponents = URLComponents(string: webFeed.url) else {
			completion(.failure(TwitterFeedProviderError.unknown))
			return
		}
		
		let api: String
		var parameters = [String: Any]()
		var isSearch = false
		
		switch urlComponents.path {
		case "", "/", "/home":
			parameters["count"] = 100
			api = "statuses/home_timeline.json"
		case "/notifications/mentions":
			api = "statuses/mentions_timeline.json"
		case "/search":
			api = "search/tweets.json"
			if let query = urlComponents.queryItems?.first(where: { $0.name == "q" })?.value {
				parameters["q"] = query
			}
			isSearch = true
		default:
			if let hashtag = deriveHashtag(urlComponents) {
				api = "search/tweets.json"
				parameters["q"] = "#\(hashtag)"
				isSearch = true
			} else {
				api = "statuses/user_timeline.json"
				parameters["exclude_replies"] = true
				if let screenName = deriveScreenName(urlComponents) {
					parameters["screen_name"] = screenName
				} else {
					completion(.failure(TwitterFeedProviderError.unknown))
					return
				}
			}
		}

		retrieveTweets(api: api, parameters: parameters, isSearch: isSearch) { result in
			switch result {
			case .success(let tweets):
				let parsedItems = self.makeParsedItems(webFeed.url, tweets)
				completion(.success(parsedItems))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	public static func buildURL(_ type: TwitterFeedType, username: String?, screenName: String?, searchField: String?) -> URL? {
		var components = URLComponents()
		components.scheme = "https"
		components.host = "twitter.com"

		switch type {
		case .homeTimeline:
			guard let username = username else {
				return nil
			}
			components.user = username
		case .mentions:
			guard let username = username else {
				return nil
			}
			components.user = username
			components.path = "/notifications/mentions"
		case .screenName:
			guard let screenName = screenName else {
				return nil
			}
			components.path = "/\(screenName)"
		case .search:
			guard let searchField = searchField else {
				return nil
			}
			components.path = "/search"
			components.queryItems = [URLQueryItem(name: "q", value: searchField)]
		}
		
		return components.url
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
	
	func deriveHashtag(_ urlComponents: URLComponents) -> String? {
		let path = urlComponents.path
		if path.starts(with: "/hashtag/"), let startIndex = path.index(path.startIndex, offsetBy: 9, limitedBy: path.endIndex), startIndex < path.endIndex {
			return String(path[startIndex..<path.endIndex])
		}
		return nil
	}
	
	func deriveScreenName(_ urlComponents: URLComponents) -> String? {
		let path = urlComponents.path
		guard !Self.reservedPaths.contains(path) else { return nil }
		
		if path.isEmpty || Self.userPaths.contains(path) {
			return screenName
		} else {
			return String(path.suffix(from: path.index(path.startIndex, offsetBy: 1)))
		}
	}
	
	func retrieveUser(screenName: String, completion: @escaping (Result<TwitterUser, Error>) -> Void) {
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
	
	func retrieveTweets(api: String, parameters: [String: Any], isSearch: Bool, completion: @escaping (Result<[TwitterStatus], Error>) -> Void) {
		let url = "\(Self.apiBase)\(api)"
		var expandedParameters = parameters
		expandedParameters["tweet_mode"] = "extended"
		
		client.get(url, parameters: expandedParameters) { result in
			switch result {
			case .success(let response):
				
				let decoder = JSONDecoder()
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = Self.dateFormat
				decoder.dateDecodingStrategy = .formatted(dateFormatter)
				
				do {
					let tweets: [TwitterStatus]
					if isSearch {
						let searchResult = try decoder.decode(TwitterSearchResult.self, from: response.data)
						if let statuses = searchResult.statuses {
							tweets = statuses
						} else {
							tweets = [TwitterStatus]()
						}
					} else {
						tweets = try decoder.decode([TwitterStatus].self, from: response.data)
					}
					completion(.success(tweets))
				} catch {
					completion(.failure(error))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func makeParsedItems(_ webFeedURL: String, _ statuses: [TwitterStatus]) -> Set<ParsedItem> {
		var parsedItems = Set<ParsedItem>()
		
		for status in statuses {
			guard let idStr = status.idStr, let statusURL = status.url else { continue }
			
			let parsedItem = ParsedItem(syncServiceID: nil,
							  uniqueID: idStr,
							  feedURL: webFeedURL,
							  url: statusURL,
							  externalURL: nil,
							  title: nil,
							  language: nil,
							  contentHTML: status.renderAsHTML(),
							  contentText: status.renderAsText(),
							  summary: nil,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: status.createdAt,
							  dateModified: nil,
							  authors: makeParsedAuthors(status.user),
							  tags: nil,
							  attachments: nil)
			parsedItems.insert(parsedItem)
		}
		
		return parsedItems
	}
	
	func makeUserURL(_ screenName: String) -> String {
		return "https://twitter.com/\(screenName)"
	}
	
	func makeParsedAuthors(_ user: TwitterUser?) -> Set<ParsedAuthor>? {
		guard let user = user else { return nil }
		return Set([ParsedAuthor(name: user.name, url: user.url, avatarURL: user.avatarURL, emailAddress: nil)])
	}
	
}
