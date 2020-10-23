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
import RSWeb

public enum TwitterFeedProviderError: LocalizedError {
	case rateLimitExceeded
	case screenNameNotFound
	case unknown
	
	public var localizedDescription: String {
		switch self {
		case .rateLimitExceeded:
			return NSLocalizedString("Twitter API rate limit has been exceeded.  Please wait a short time and try again.", comment: "Rate Limit")
		case .screenNameNotFound:
			return NSLocalizedString("Unable to determine screen name.", comment: "Screen name")
		case .unknown:
			return NSLocalizedString("An unknown Twitter Feed Provider error has occurred.", comment: "Unknown error")
		}
	}
}

public enum TwitterFeedType: Int {
	case homeTimeline = 0
	case mentions = 1
	case screenName = 2
	case search = 3
}

public final class TwitterFeedProvider: FeedProvider {

	private static let homeURL = "https://www.twitter.com"
	private static let server = "api.twitter.com"
	private static let apiBase = "https://api.twitter.com/1.1/"
	private static let userAgentHeaders = UserAgent.headers() as! [String: String]
	private static let dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
	
	private static let userPaths = ["/home", "/notifications"]
	private static let reservedPaths = ["/search", "/explore", "/messages", "/i", "/compose"]
	
	private var parsingQueue = DispatchQueue(label: "TwitterFeedProvider parse queue")

	public var screenName: String
	
	private var oauthToken: String
	private var oauthTokenSecret: String

	private var client: OAuthSwiftClient
	
	private var rateLimitRemaining: Int?
	private var rateLimitReset: Date?
	
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
		
		client = OAuthSwiftClient(consumerKey: SecretsManager.provider.twitterConsumerKey,
								  consumerSecret: SecretsManager.provider.twitterConsumerSecret,
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
		
		client = OAuthSwiftClient(consumerKey: SecretsManager.provider.twitterConsumerKey,
								  consumerSecret: SecretsManager.provider.twitterConsumerSecret,
								  oauthToken: oauthToken,
								  oauthTokenSecret: oauthTokenSecret,
								  version: .oauth1)
	}

	public func ability(_ urlComponents: URLComponents) -> FeedProviderAbility {
		guard urlComponents.host?.hasSuffix("twitter.com") ?? false else {
			return .none
		}
		
		if let username = urlComponents.user {
			if username == screenName {
				return .owner
			} else {
				return .none
			}
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

	public func metaData(_ urlComponents: URLComponents, completion: @escaping (Result<FeedProviderFeedMetaData, Error>) -> Void) {
		switch urlComponents.path {
			
		case "", "/", "/home":
			let name = NSLocalizedString("Twitter Timeline", comment: "Twitter Timeline")
			completion(.success(FeedProviderFeedMetaData(name: name, homePageURL: Self.homeURL)))
			
		case "/notifications/mentions":
			let name = NSLocalizedString("Twitter Mentions", comment: "Twitter Mentions")
			completion(.success(FeedProviderFeedMetaData(name: name, homePageURL: Self.homeURL)))

		case "/search":
			if let query = urlComponents.queryItems?.first(where: { $0.name == "q" })?.value {
				let localized = NSLocalizedString("Twitter Search: %@", comment: "Twitter Search")
				let name = NSString.localizedStringWithFormat(localized as NSString, query) as String
				completion(.success(FeedProviderFeedMetaData(name: name, homePageURL: Self.homeURL)))
			} else {
				let name = NSLocalizedString("Twitter Search", comment: "Twitter Search")
				completion(.success(FeedProviderFeedMetaData(name: name, homePageURL: Self.homeURL)))
			}
			
		default:
			if let hashtag = deriveHashtag(urlComponents) {
				completion(.success(FeedProviderFeedMetaData(name: "#\(hashtag)", homePageURL: Self.homeURL)))
			} else if let listID = deriveListID(urlComponents) {
				retrieveList(listID: listID) { result in
					switch result {
					case .success(let list):
						if let userName = list.name {
							var urlComponents = URLComponents(string: Self.homeURL)
							urlComponents?.path = "/i/lists/\(listID)"
							completion(.success(FeedProviderFeedMetaData(name: userName, homePageURL: urlComponents?.url?.absoluteString)))
						} else {
							completion(.failure(TwitterFeedProviderError.screenNameNotFound))
						}
					case .failure(let error):
						completion(.failure(error))
					}
				}
			} else if let screenName = deriveScreenName(urlComponents) {
				retrieveUser(screenName: screenName) { result in
					switch result {
					case .success(let user):
						if let userName = user.name {
							var urlComponents = URLComponents(string: Self.homeURL)
							urlComponents?.path = "/\(screenName)"
							completion(.success(FeedProviderFeedMetaData(name: userName, homePageURL: urlComponents?.url?.absoluteString)))
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
		
		if let sinceToken = webFeed.sinceToken, let sinceID = Int(sinceToken) {
			parameters["since_id"] = sinceID
		}
		
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
			} else if let listID = deriveListID(urlComponents) {
				api = "lists/statuses.json"
				parameters["list_id"] = listID
			} else if let screenName = deriveScreenName(urlComponents) {
				api = "statuses/user_timeline.json"
				parameters["exclude_replies"] = true
				parameters["screen_name"] = screenName
			} else {
				completion(.failure(TwitterFeedProviderError.unknown))
				return
			}
		}

		retrieveTweets(api: api, parameters: parameters, isSearch: isSearch) { result in
			switch result {
			case .success(let statuses):
				if let sinceID = statuses.first?.idStr {
					webFeed.sinceToken = sinceID
				}
				self.parsingQueue.async {
					let parsedItems = self.makeParsedItems(webFeed.url, statuses)
					DispatchQueue.main.async {
						completion(.success(parsedItems))
					}
				}
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
	
	public static var callbackURL: URL {
		return URL(string: "netnewswire://")!
	}
	
	public static var oauth1Swift: OAuth1Swift {
		return OAuth1Swift(
			consumerKey: SecretsManager.provider.twitterConsumerKey,
			consumerSecret: SecretsManager.provider.twitterConsumerSecret,
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
	
	func deriveListID(_ urlComponents: URLComponents) -> String? {
		let path = urlComponents.path
		guard path.starts(with: "/i/lists/") else { return nil }
		return String(path.suffix(from: path.index(path.startIndex, offsetBy: 9)))
	}
	
	func retrieveUser(screenName: String, completion: @escaping (Result<TwitterUser, Error>) -> Void) {
		let url = "\(Self.apiBase)users/show.json"
		let parameters = ["screen_name": screenName]
		
		client.get(url, parameters: parameters, headers: Self.userAgentHeaders) { result in
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
	
	func retrieveList(listID: String, completion: @escaping (Result<TwitterList, Error>) -> Void) {
		let url = "\(Self.apiBase)lists/show.json"
		let parameters = ["list_id": listID]
		
		client.get(url, parameters: parameters, headers: Self.userAgentHeaders) { result in
			switch result {
			case .success(let response):
				let decoder = JSONDecoder()
				do {
					let collection = try decoder.decode(TwitterList.self, from: response.data)
					completion(.success(collection))
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
		
		if let remaining = rateLimitRemaining, let reset = rateLimitReset, remaining < 1 && reset > Date() {
			completion(.failure(TwitterFeedProviderError.rateLimitExceeded))
			return
		}

		client.get(url, parameters: expandedParameters, headers: Self.userAgentHeaders) { result in
			switch result {
			case .success(let response):
				
				let decoder = JSONDecoder()
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = Self.dateFormat
				decoder.dateDecodingStrategy = .formatted(dateFormatter)

				if let remaining = response.response.value(forHTTPHeaderField: "x-rate-limit-remaining") {
					self.rateLimitRemaining = Int(remaining) ?? 0
				}
				if let reset = response.response.value(forHTTPHeaderField: "x-rate-limit-reset") {
					self.rateLimitReset = Date(timeIntervalSince1970: Double(reset) ?? 0)
				}

				self.parsingQueue.async {
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
						DispatchQueue.main.async {
							completion(.success(tweets))
						}
					} catch {
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
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
