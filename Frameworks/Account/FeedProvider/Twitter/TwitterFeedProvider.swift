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
		
		let bestUserName = username != nil ? username : urlComponents.user
		if bestUserName == screenName {
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
		let api = "statuses/home_timeline.json"

		retrieveTweets(api: api) { result in
			switch result {
			case .success(let tweets):
				let parsedItems = self.makeParsedItems(webFeed.url, tweets)
				completion(.success(parsedItems))
			case .failure(let error):
				completion(.failure(error))
			}
		}
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
	
	func retrieveTweets(api: String, completion: @escaping (Result<[Tweet], Error>) -> Void) {
		let url = "\(Self.apiBase)\(api)"
		let parameters = [String: Any]()
		
		client.get(url, parameters: parameters) { result in
			switch result {
			case .success(let response):
				let decoder = JSONDecoder()
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = Self.dateFormat
				decoder.dateDecodingStrategy = .formatted(dateFormatter)
				do {
					let tweets = try decoder.decode([Tweet].self, from: response.data)
					completion(.success(tweets))
				} catch {
					completion(.failure(error))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func makeParsedItems(_ webFeedURL: String, _ tweets: [Tweet]) -> Set<ParsedItem> {
		var parsedItems = Set<ParsedItem>()
		
		for tweet in tweets {
			guard let idStr = tweet.idStr, let userScreenName = tweet.user.screenName else { continue }
			
			let userURL = makeUserURL(userScreenName)
			
			let parsedItem = ParsedItem(syncServiceID: idStr,
							  uniqueID: idStr,
							  feedURL: webFeedURL,
							  url: "\(userURL)/status/\(idStr)",
							  externalURL: nil,
							  title: nil,
							  language: nil,
							  contentHTML: makeTweetHTML(tweet),
							  contentText: makeTweetText(tweet),
							  summary: nil,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: tweet.createdAt,
							  dateModified: nil,
							  authors: makeParsedAuthors(tweet.user),
							  tags: nil,
							  attachments: nil)
			parsedItems.insert(parsedItem)
		}
		
		return parsedItems
	}
	
	func makeUserURL(_ screenName: String) -> String {
		return "https://twitter.com/\(screenName)"
	}
	
	func makeParsedAuthors(_ user: TwitterUser) -> Set<ParsedAuthor> {
		return Set([ParsedAuthor(name: user.name, url: makeUserURL(user.screenName!), avatarURL: user.avatarURL, emailAddress: nil)])
	}
	
	func makeTweetText(_ tweet: Tweet) -> String? {
		if tweet.truncated, let extendedText = tweet.extendedTweet?.fullText {
			if let displayRange = tweet.extendedTweet?.displayTextRange, displayRange.count > 1 {
				let startIndex = extendedText.index(extendedText.startIndex, offsetBy: displayRange[0])
				let endIndex = extendedText.index(extendedText.startIndex, offsetBy: displayRange[1])
				return String(extendedText[startIndex...endIndex])
			} else {
				return extendedText
			}
		} else {
			if let text = tweet.text, let displayRange = tweet.displayTextRange {
				let startIndex = text.index(text.startIndex, offsetBy: displayRange[0])
				let endIndex = text.index(text.startIndex, offsetBy: displayRange[1])
				return String(text[startIndex...endIndex])
			} else {
				return tweet.text
			}
		}
	}
	
	func makeTweetHTML(_ tweet: Tweet) -> String? {
		return nil
	}
	
}
