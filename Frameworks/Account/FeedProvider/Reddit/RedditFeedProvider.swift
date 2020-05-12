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
	case rateLimitExceeded
	case unknown
	
	public var localizedDescription: String {
		switch self {
		case .rateLimitExceeded:
			return NSLocalizedString("Reddit API rate limit has been exceeded.  Please wait a short time and try again.", comment: "Rate Limit")
		case .unknown:
			return NSLocalizedString("A Reddit Feed Provider error has occurred.", comment: "Unknown error")
		}
	}
}

public enum RedditFeedType: Int {
	case home = 0
	case popular = 1
	case all = 2
	case subreddit = 3
}

public final class RedditFeedProvider: FeedProvider {

	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "RedditFeedProvider")

	private static let homeURL = "https://www.reddit.com"
	private static let server = "www.reddit.com"
	private static let apiBase = "https://oauth.reddit.com"
	private static let userAgentHeaders = UserAgent.headers() as! [String: String]
	
	private static let pseudoSubreddits = [
		"popular": NSLocalizedString("Popular", comment: "Popular"),
		"all": NSLocalizedString("All", comment: "All")
	]
	
	public var username: String?
	
	private var oauthToken: String
	private var oauthRefreshToken: String

    private var oauthSwift: OAuth2Swift?
	private var client: OAuthSwiftClient? {
		return oauthSwift?.client
	}

	private var rateLimitRemaining: Int?
	private var rateLimitReset: Date?
	
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
		guard urlComponents.path.hasPrefix("/r/") else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}

		subreddit(urlComponents) { result in
			switch result {
			case .success(let subreddit):
				if let iconURL = subreddit.data?.iconURL, !iconURL.isEmpty {
					completion(.success(iconURL))
				} else {
					completion(.failure(RedditFeedProviderError.unknown))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	public func metaData(_ urlComponents: URLComponents, completion: @escaping (Result<FeedProviderFeedMetaData, Error>) -> Void) {
		let path = urlComponents.path

		// Reddit Home
		let splitPath = path.split(separator: "/")
		if path == "" || path == "/" || (splitPath.count == 1 && RedditSort(rawValue: String(splitPath[0])) != nil) {
			let name = NSLocalizedString("Reddit Home", comment: "Reddit Home")
			let metaData = FeedProviderFeedMetaData(name: name, homePageURL: Self.homeURL)
			completion(.success(metaData))
			return
		}
		
		// Subreddits
		guard splitPath.count > 1, splitPath.count < 4, splitPath[0] == "r" else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}

		if splitPath.count == 3 && RedditSort(rawValue: String(splitPath[2])) == nil {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		let homePageURL = "https://www.reddit.com/\(splitPath[0])/\(splitPath[1])"
		
		// Reddit Popular, Reddit All, etc...
		if let subredditName = Self.pseudoSubreddits[String(splitPath[1])] {
			let localized = NSLocalizedString("Reddit %@", comment: "Reddit")
			let name = NSString.localizedStringWithFormat(localized as NSString, subredditName) as String
			let metaData = FeedProviderFeedMetaData(name: name, homePageURL: homePageURL)
			completion(.success(metaData))
			return
		}
		
		subreddit(urlComponents) { result in
			switch result {
			case .success(let subreddit):
				if let displayName = subreddit.data?.displayName {
					completion(.success(FeedProviderFeedMetaData(name: displayName, homePageURL: homePageURL)))
				} else {
					completion(.failure(RedditFeedProviderError.unknown))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}

	}
	
	public func refresh(_ webFeed: WebFeed, completion: @escaping (Result<Set<ParsedItem>, Error>) -> Void) {
		guard let urlComponents = URLComponents(string: webFeed.url) else {
			completion(.failure(TwitterFeedProviderError.unknown))
			return
		}
		
		let api: String
		if urlComponents.path.isEmpty {
			api = "/.json"
		} else {
			api = "\(urlComponents.path).json"
		}

		let splitPath = urlComponents.path.split(separator: "/")
		let identifySubreddit: Bool
		if splitPath.count > 1 {
			if Self.pseudoSubreddits.keys.contains(String(splitPath[1])) {
				identifySubreddit = true
			} else {
				identifySubreddit = !urlComponents.path.hasPrefix("/r/")
			}
		} else {
			identifySubreddit = true
		}
		
		fetch(api: api, parameters: [:], resultType: RedditLinkListing.self) { result in
			switch result {
			case .success(let linkListing):
				let parsedItems = self.makeParsedItems(webFeed.url, identifySubreddit, linkListing)
				completion(.success(parsedItems))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	public static func create(tokenSuccess: OAuthSwift.TokenSuccess, completion: @escaping (Result<RedditFeedProvider, Error>) -> Void) {
		let oauthToken = tokenSuccess.credential.oauthToken
		let oauthRefreshToken = tokenSuccess.credential.oauthRefreshToken
		let redditFeedProvider = RedditFeedProvider(oauthToken: oauthToken, oauthRefreshToken: oauthRefreshToken)
		
		redditFeedProvider.fetch(api: "/api/v1/me", resultType: RedditMe.self) { result in
			switch result {
			case .success(let user):
				guard let username = user.name else {
					completion(.failure(RedditFeedProviderError.unknown))
					return
				}
				
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
	
	public static func buildURL(_ type: RedditFeedType, username: String?, subreddit: String?, sort: RedditSort) -> URL? {
		var components = URLComponents()
		components.scheme = "https"
		components.host = "www.reddit.com"

		switch type {
		case .home:
			guard let username = username else {
				return nil
			}
			components.user = username
			components.path = "/\(sort.rawValue)"
		case .popular:
			components.path = "/r/popular/\(sort.rawValue)"
		case .all:
			components.path = "/r/all/\(sort.rawValue)"
		case .subreddit:
			guard let subreddit = subreddit else {
				return nil
			}
			components.path = "/r/\(subreddit)/\(sort.rawValue)"
		}
		
		return components.url
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
	
	func subreddit(_ urlComponents: URLComponents, completion: @escaping (Result<RedditSubreddit, Error>) -> Void) {
		let splitPath = urlComponents.path.split(separator: "/")
		guard splitPath.count > 1 else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		let secondElement = String(splitPath[1])
		let api = "/r/\(secondElement)/about.json"
		
		fetch(api: api, parameters: [:], resultType: RedditSubreddit.self, completion: completion)
	}

	func fetch<R: Decodable>(api: String, parameters: [String: Any] = [:], resultType: R.Type, completion: @escaping (Result<R, Error>) -> Void) {
		guard let client = client else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		if let remaining = rateLimitRemaining, let reset = rateLimitReset, remaining < 1 && reset > Date() {
			completion(.failure(RedditFeedProviderError.rateLimitExceeded))
			return
		}
		
		let url = "\(Self.apiBase)\(api)"

		var expandedParameters = parameters
		expandedParameters["raw_json"] = "1"

		client.get(url, parameters: expandedParameters, headers: Self.userAgentHeaders) { result in
			switch result {
			case .success(let response):
				
//				let jsonString = String(data: response.data, encoding: .utf8)
//				let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("reddit.json")
//				print("******** writing to: \(url.path)")
//				try? jsonString?.write(toFile: url.path, atomically: true, encoding: .utf8)

				if let remaining = response.response.value(forHTTPHeaderField: "X-Ratelimit-Remaining") {
					self.rateLimitRemaining = Int(remaining)
				} else {
					self.rateLimitRemaining = nil
				}
				
				if let reset = response.response.value(forHTTPHeaderField: "X-Ratelimit-Reset") {
					self.rateLimitReset = Date(timeIntervalSinceNow: Double(reset) ?? 0)
				} else {
					self.rateLimitReset = nil
				}

				DispatchQueue.global(qos: .background).async {
					let decoder = JSONDecoder()
					do {
						let result = try decoder.decode(resultType, from: response.data)
						DispatchQueue.main.async {
							completion(.success(result))
						}
					} catch {
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
			
			case .failure(let oathError):
				self.handleFailure(error: oathError) { error in
					if let error = error {
						completion(.failure(error))
					} else {
						self.fetch(api: api, parameters: parameters, resultType: resultType, completion: completion)
					}
				}
			}
		}
	}
	
	func makeParsedItems(_ webFeedURL: String,_ identifySubreddit: Bool, _ linkListing: RedditLinkListing) -> Set<ParsedItem> {
		var parsedItems = Set<ParsedItem>()

		guard let linkDatas = linkListing.data?.children?.compactMap({ $0.data }), !linkDatas.isEmpty else {
			return parsedItems
		}

		for linkData in linkDatas {
			guard let permalink = linkData.permalink else { continue }

			let parsedItem = ParsedItem(syncServiceID: nil,
							  uniqueID: permalink,
							  feedURL: webFeedURL,
							  url: "https://www.reddit.com\(permalink)",
							  externalURL: linkData.url,
							  title: linkData.title,
							  language: nil,
							  contentHTML: linkData.renderAsHTML(identifySubreddit: identifySubreddit),
							  contentText: linkData.selfText,
							  summary: nil,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: linkData.createdDate,
							  dateModified: nil,
							  authors: makeParsedAuthors(linkData.author),
							  tags: nil,
							  attachments: nil)
			parsedItems.insert(parsedItem)
		}

		return parsedItems
	}
	
	func makeParsedAuthors(_ username: String?) -> Set<ParsedAuthor>? {
		guard let username = username else { return nil }
		var urlComponents = URLComponents(string: "https://www.reddit.com")
		urlComponents?.path = "/u/\(username)"
		let userURL = urlComponents?.url?.absoluteString
		return Set([ParsedAuthor(name: "u/\(username)", url: userURL, avatarURL: nil, emailAddress: nil)])
	}
	
    func handleFailure(error: OAuthSwiftError, completion: @escaping (Error?) -> Void) {
		if case .tokenExpired = error {

			os_log(.debug, log: self.log, "Access token expired, attempting to renew...")
			
			oauthSwift?.renewAccessToken(withRefreshToken: oauthRefreshToken) { [weak self] result in
				guard let strongSelf = self, let username = strongSelf.username else {
					completion(nil)
					return
				}
				
				switch result {
				case .success(let tokenSuccess):
					strongSelf.oauthToken = tokenSuccess.credential.oauthToken
					strongSelf.oauthRefreshToken = tokenSuccess.credential.oauthRefreshToken
					do {
						try Self.storeCredentials(username: username, oauthToken: strongSelf.oauthToken, oauthRefreshToken: strongSelf.oauthRefreshToken)
						os_log(.debug, log: strongSelf.log, "Access token renewed.")
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
