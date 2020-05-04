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
		guard urlComponents.path.hasPrefix("/r/"), let secondElement = extractSecondElement(path: urlComponents.path) else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		let api = "/r/\(secondElement)/about.json"
		
		fetch(api: api, parameters: [:], resultType: RedditSubreddit.self) { result in
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
		
		let api = "\(urlComponents.path).json"
		
		fetch(api: api, parameters: [:], resultType: RedditLinkListing.self) { result in
			switch result {
			case .success(let linkListing):
				let parsedItems = self.makeParsedItems(webFeed.url, linkListing)
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
	
	func fetch<R: Decodable>(api: String, parameters: [String: Any] = [:], resultType: R.Type, completion: @escaping (Result<R, Error>) -> Void) {
		guard let client = client else {
			completion(.failure(RedditFeedProviderError.unknown))
			return
		}
		
		let url = "\(Self.apiBase)\(api)"

		var expandedParameters = parameters
		expandedParameters["raw_json"] = "1"

		client.get(url, parameters: expandedParameters, headers: Self.userAgentHeaders) { result in
			switch result {
			case .success(let response):
				
				let jsonString = String(data: response.data, encoding: .utf8)
				let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("reddit.json")
				print("******** writing to: \(url.path)")
				try? jsonString?.write(toFile: url.path, atomically: true, encoding: .utf8)

				let decoder = JSONDecoder()
				
				do {
					let result = try decoder.decode(resultType, from: response.data)
					completion(.success(result))
				} catch {
					completion(.failure(error))
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
	
	func makeParsedItems(_ webFeedURL: String, _ linkListing: RedditLinkListing) -> Set<ParsedItem> {
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
							  contentHTML: linkData.renderAsHTML(),
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
	
	func extractSecondElement(path: String) -> String? {
		let scanner = Scanner(string: path)
		if let _ = scanner.scanString("/"),
			let _ = scanner.scanUpToString("/"),
			let _ = scanner.scanString("/"),
			let secondElement = scanner.scanUpToString("/") {
				return secondElement
		}
		return nil
	}
	
	static func storeCredentials(username: String, oauthToken: String, oauthRefreshToken: String) throws {
		let tokenCredentials = Credentials(type: .oauthAccessToken, username: username, secret: oauthToken)
		try CredentialsManager.storeCredentials(tokenCredentials, server: Self.server)
		let tokenSecretCredentials = Credentials(type: .oauthRefreshToken, username: username, secret: oauthRefreshToken)
		try CredentialsManager.storeCredentials(tokenSecretCredentials, server: Self.server)
	}
	
}
