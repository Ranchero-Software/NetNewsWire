//
//  FeedlyAPICaller.swift
//  Account
//
//  Created by Kiel Gillard on 13/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Secrets

public protocol FeedlyAPICallerDelegate: AnyObject {

	/// Implemented by the `FeedlyAccountDelegate` reauthorize the client with a fresh OAuth token so the client can retry the unauthorized request.
	/// Pass `true` to the completion handler if the failing request should be retried with a fresh token or `false` if the unauthorized request should complete with the original failure error.
	@MainActor func reauthorizeFeedlyAPICaller(_ caller: FeedlyAPICaller) async -> Bool
}

@MainActor public final class FeedlyAPICaller {

	public enum API {
		case sandbox
		case cloud

		public var baseUrlComponents: URLComponents {
			var components = URLComponents()
			components.scheme = "https"
			switch self{
			case .sandbox:
				// https://groups.google.com/forum/#!topic/feedly-cloud/WwQWMgDmOuw
				components.host = "sandbox7.feedly.com"
			case .cloud:
				// https://developer.feedly.com/cloud/
				components.host = "cloud.feedly.com"
			}
			return components
		}
		
		public func oauthAuthorizationClient(secretsProvider: SecretsProvider) -> OAuthAuthorizationClient {
			switch self {
			case .sandbox:
				return .feedlySandboxClient
			case .cloud:
				return OAuthAuthorizationClient.feedlyCloudClient(secretsProvider: secretsProvider)
			}
		}
	}
	
	private let transport: Transport
	private let baseURLComponents: URLComponents
	private let uriComponentAllowed: CharacterSet
	private let secretsProvider: SecretsProvider
	private let api: FeedlyAPICaller.API

	public init(transport: Transport, api: API, secretsProvider: SecretsProvider) {
		self.transport = transport
		self.baseURLComponents = api.baseUrlComponents
		self.secretsProvider = secretsProvider
		self.api = api

		var urlHostAllowed = CharacterSet.urlHostAllowed
		urlHostAllowed.remove("+")
		uriComponentAllowed = urlHostAllowed
	}
	
	public weak var delegate: FeedlyAPICallerDelegate?

	public var credentials: Credentials?
	
	public var server: String? {
		return baseURLComponents.host
	}
	
	func cancelAll() {
		transport.cancelAll()
	}
	
	private var isSuspended = false
	
	/// Cancels all pending requests rejects any that come in later
	public func suspend() {
		transport.cancelAll()
		isSuspended = true
	}
	
	public func resume() {
		isSuspended = false
	}
	
	private func send<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type) async throws -> (HTTPURLResponse, R?) {

		try await withCheckedThrowingContinuation { continuation in
			self.send(request: request, resultType: resultType, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in

				switch result {
				case .success(let response):
					continuation.resume(returning: response)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func send<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys, completion: @escaping @Sendable (Result<(HTTPURLResponse, R?), Error>) -> Void) {

		transport.send(request: request, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding) { [weak self] result in

			Task { @MainActor [weak self] in

				switch result {
				case .success:
					completion(result)
				case .failure(let error):
					switch error {
					case TransportError.httpError(let statusCode) where statusCode == 401:

						assert(self == nil ? true : self?.delegate != nil, "Check the delegate is set.")

						guard let self = self, let delegate = self.delegate else {
							completion(result)
							return
						}

						/// Capture the credentials before the reauthorization to check for a change.
						let credentialsBefore = self.credentials

						let isReauthorizedAndShouldRetry = await delegate.reauthorizeFeedlyAPICaller(self)
						guard isReauthorizedAndShouldRetry else {
							completion(result)
							return
						}

						// Check for a change. Not only would it help debugging, but it'll also catch an infinitely recursive attempt to refresh.
						guard let accessToken = self.credentials?.secret, accessToken != credentialsBefore?.secret else {
							assertionFailure("Could not update the request with a new OAuth token. Did \(String(describing: self.delegate)) set them on \(self)?")
							completion(result)
							return
						}

						var reauthorizedRequest = request
						reauthorizedRequest.setValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)

						self.send(request: reauthorizedRequest, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding, completion: completion)

					default:
						completion(result)
					}
				}
			}
		}
	}

	public func importOPML(_ opmlData: Data) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/opml", method: HTTPMethod.post, includeJSONHeaders: false, includeOAuthToken: true)
		request.addValue("text/xml", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.acceptType)
		request.httpBody = opmlData

		let (httpResponse, _) = try await send(request: request, resultType: String.self)
		if httpResponse.statusCode != HTTPResponseCode.OK {
			throw URLError(.cannotDecodeContentData)
		}
	}
	
	public func createCollection(named label: String) async throws -> FeedlyCollection {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/collections", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: true)

		struct CreateCollectionBody: Encodable {
			var label: String
		}
		try addObject(CreateCollectionBody(label: label), to: &request)

		let (httpResponse, collections) = try await send(request: request, resultType: [FeedlyCollection].self)

		guard let collection = collections?.first, httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
		return collection
	}

	public func renameCollection(with id: String, to name: String) async throws -> FeedlyCollection {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/collections", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: true)

		struct RenameCollectionBody: Encodable {
			var id: String
			var label: String
		}
		try addObject(RenameCollectionBody(id: id, label: name), to: &request)

		let (httpResponse, collections) = try await send(request: request, resultType: [FeedlyCollection].self)

		guard let collection = collections?.first, httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
		return collection
	}

	private func encodeForURLPath(_ pathComponent: String) -> String? {
		return pathComponent.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed)
	}
	
	public func deleteCollection(with id: String) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		guard let encodedID = encodeForURLPath(id) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(id)
		}
		let request = try urlRequest(path: "/v3/collections/\(encodedID)", method: HTTPMethod.delete, includeJSONHeaders: true, includeOAuthToken: true)

		let (httpResponse, _) = try await send(request: request, resultType: Optional<FeedlyCollection>.self)

		guard httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
	}
	
	public func removeFeed(_ feedID: String, fromCollectionWith collectionID: String) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		guard let encodedCollectionID = encodeForURLPath(collectionID) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(collectionID)
		}
		
		var components = baseURLComponents
		components.percentEncodedPath = "/v3/collections/\(encodedCollectionID)/feeds/.mdelete"
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = HTTPMethod.delete
		addJSONHeaders(&request)
		try addOAuthAccessToken(&request)

		struct RemovableFeed: Encodable {
			let id: String
		}
		try addObject([RemovableFeed(id: feedID)], to: &request)

        // `resultType` is optional because the Feedly API has gone from returning an array of removed feeds to returning `null`.
        // https://developer.feedly.com/v3/collections/#remove-multiple-feeds-from-a-personal-collection
		let (httpResponse, _) = try await send(request: request, resultType: Optional<[FeedlyFeed]>.self)

		guard httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
	}

	@discardableResult
	@MainActor public func addFeed(with feedID: FeedlyFeedResourceID, title: String? = nil, toCollectionWith collectionID: String) async throws -> [FeedlyFeed] {

		guard !isSuspended else { throw TransportError.suspended }

		guard let encodedID = encodeForURLPath(collectionID) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(collectionID)
		}
		var components = baseURLComponents
		components.percentEncodedPath = "/v3/collections/\(encodedID)/feeds"
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = HTTPMethod.put
		addJSONHeaders(&request)
		try addOAuthAccessToken(&request)

		struct AddFeedBody: Encodable {
			var id: String
			var title: String?
		}
		try addObject(AddFeedBody(id: feedID.id, title: title), to: &request)

		let (_, collectionFeeds) = try await send(request: request, resultType: [FeedlyFeed].self)
		guard let collectionFeeds else {
			throw URLError(.cannotDecodeContentData)
		}

		return collectionFeeds
	}

	/// https://tools.ietf.org/html/rfc6749#section-4.1

	/// Provides the URL request that allows users to consent to the client having access to their information. Typically loaded by a web view.
	/// - Parameter request: The information about the client requesting authorization to be granted access tokens.
	/// - Parameter baseUrlComponents: The scheme and host of the url except for the path.
	static public func authorizationCodeURLRequest(for request: OAuthAuthorizationRequest, baseUrlComponents: URLComponents) -> URLRequest {

		var components = baseUrlComponents
		components.path = "/v3/auth/auth"
		components.queryItems = request.queryItems
		
		guard let url = components.url else {
			assert(components.scheme != nil)
			assert(components.host != nil)
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		return request
	}
	
	/// Performs the request for the access token given an authorization code.
	/// - Parameter authorizationRequest: The authorization code and other information the authorization server requires to grant the client access tokens on the user's behalf.
	/// - Returns: On success, the access token response appropriate for concrete type's service. On failure, throws possibly a `URLError` or `OAuthAuthorizationErrorResponse` value.
	public func requestAccessToken(_ authorizationRequest: OAuthAccessTokenRequest) async throws -> FeedlyOAuthAccessTokenResponse {

		guard !isSuspended else { throw TransportError.suspended }
		
		var request = try urlRequest(path: "/v3/auth/token", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: false)
		try addObject(authorizationRequest, keyEncodingStrategy: .convertToSnakeCase, to: &request)

		let (_, tokenResponse) = try await send(request: request, resultType: FeedlyOAuthAccessTokenResponse.self)
		guard let tokenResponse else {
			throw URLError(.cannotDecodeContentData)
		}

		return tokenResponse
	}

	/// Access tokens expire. Perform a request for a fresh access token given the long life refresh token received when authorization was granted.
	///
	/// [Documentation](https://tools.ietf.org/html/rfc6749#section-6)
	///
	/// - Parameter refreshRequest: The refresh token and other information the authorization server requires to grant the client fresh access tokens on the user's behalf.
	/// - Returns: On success, the access token response appropriate for concrete type's service. Both the access and refresh token should be stored, preferably on the Keychain. On failure, throws an Error.
	public func refreshAccessToken(_ refreshRequest: OAuthRefreshAccessTokenRequest) async throws -> FeedlyOAuthAccessTokenResponse {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/auth/token", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: false)
		try addObject(refreshRequest, keyEncodingStrategy: .convertToSnakeCase, to: &request)

		let (_, tokenResponse) = try await send(request: request, resultType: FeedlyOAuthAccessTokenResponse.self)
		guard let tokenResponse else {
			throw URLError(.cannotDecodeContentData)
		}

		return tokenResponse
	}

	public func getCollections() async throws -> Set<FeedlyCollection> {

		guard !isSuspended else { throw TransportError.suspended }

		let request = try urlRequest(path: "/v3/collections", method: HTTPMethod.get, includeJSONHeaders: true, includeOAuthToken: true)

		let (_, collections) = try await send(request: request, resultType: [FeedlyCollection].self)
		guard let collections else {
			throw URLError(.cannotDecodeContentData)
		}
		
		return Set(collections)
	}

	@MainActor public func getStreamContents(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStream {

		guard !isSuspended else { throw TransportError.suspended }

		var components = baseURLComponents
		components.path = "/v3/streams/contents"
		
		var queryItems = [URLQueryItem]()
		
		if let date = newerThan {
			let value = String(Int(date.timeIntervalSince1970 * 1000))
			let queryItem = URLQueryItem(name: "newerThan", value: value)
			queryItems.append(queryItem)
		}
		
		if let flag = unreadOnly {
			let value = flag ? "true" : "false"
			let queryItem = URLQueryItem(name: "unreadOnly", value: value)
			queryItems.append(queryItem)
		}
		
		if let value = continuation, !value.isEmpty {
			let queryItem = URLQueryItem(name: "continuation", value: value)
			queryItems.append(queryItem)
		}
		
		queryItems.append(contentsOf: [
			URLQueryItem(name: "count", value: "1000"),
			URLQueryItem(name: "streamId", value: resource.id),
		])
		
		components.queryItems = queryItems
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		addJSONHeaders(&request)
		try addOAuthAccessToken(&request)

		let (_, collections) = try await send(request: request, resultType: FeedlyStream.self)

		guard let collections else {
			throw URLError(.cannotDecodeContentData)
		}

		return collections
	}

	@MainActor public func getStreamIDs(for resource: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStreamIDs {

		guard !isSuspended else { throw TransportError.suspended }

		var components = baseURLComponents
		components.path = "/v3/streams/ids"

		var queryItems = [URLQueryItem]()
		
		if let date = newerThan {
			let value = String(Int(date.timeIntervalSince1970 * 1000))
			let queryItem = URLQueryItem(name: "newerThan", value: value)
			queryItems.append(queryItem)
		}
		
		if let flag = unreadOnly {
			let value = flag ? "true" : "false"
			let queryItem = URLQueryItem(name: "unreadOnly", value: value)
			queryItems.append(queryItem)
		}
		
		if let value = continuation, !value.isEmpty {
			let queryItem = URLQueryItem(name: "continuation", value: value)
			queryItems.append(queryItem)
		}
		
		queryItems.append(contentsOf: [
			URLQueryItem(name: "count", value: "10000"),
			URLQueryItem(name: "streamId", value: resource.id),
		])
		
		components.queryItems = queryItems
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		addJSONHeaders(&request)
		try addOAuthAccessToken(&request)

		let (_, collections) = try await send(request: request, resultType: FeedlyStreamIDs.self)

		guard let collections else {
			throw URLError(.cannotDecodeContentData)
		}

		return collections
	}

	@MainActor public func getEntries(for ids: Set<String>) async throws -> [FeedlyEntry] {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/entries/.mget", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: true)
		let body = Array(ids)
		try addObject(body, to: &request)

		let (_, entries) = try await send(request: request, resultType: [FeedlyEntry].self)

		guard let entries else {
			throw URLError(.cannotDecodeContentData)
		}

		return entries
	}

	private struct MarkerEntriesBody: Encodable {
		let type = "entries"
		var action: String
		var entryIDs: [String]
	}
	
	public func mark(_ articleIDs: Set<String>, as action: FeedlyMarkAction) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		let articleIDChunks = Array(articleIDs).chunked(into: 300)

		for articleIDChunk in articleIDChunks {

			var request = try urlRequest(path: "/v3/markers", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: true)
			let body = MarkerEntriesBody(action: action.actionValue, entryIDs: Array(articleIDChunk))
			try addObject(body, to: &request)

			let (httpResponse, _) = try await send(request: request, resultType: String.self)
			if httpResponse.statusCode != 200 {
				throw URLError(.cannotDecodeContentData)
			}
		}
	}

	public func getFeeds(for query: String, count: Int, localeIdentifier: String) async throws -> FeedlyFeedsSearchResponse {

		guard !isSuspended else { throw TransportError.suspended }

		var components = baseURLComponents
		components.path = "/v3/search/feeds"
		components.queryItems = [
			URLQueryItem(name: "query", value: query),
			URLQueryItem(name: "count", value: String(count)),
			URLQueryItem(name: "locale", value: localeIdentifier)
		]
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		addJSONHeaders(&request)

		let (_, searchResponse) = try await send(request: request, resultType: FeedlyFeedsSearchResponse.self)

		guard let searchResponse else {
			throw URLError(.cannotDecodeContentData)
		}

		return searchResponse
	}
	
	public func logout() async throws {

		guard !isSuspended else { throw TransportError.suspended }

		let request = try urlRequest(path: "/v3/auth/logout", method: HTTPMethod.post, includeJSONHeaders: true, includeOAuthToken: true)

		let (httpResponse, _) = try await send(request: request, resultType: String.self)
		if httpResponse.statusCode != HTTPResponseCode.OK {
			throw URLError(.cannotDecodeContentData)
		}
	}
}

// MARK: - OAuth

extension FeedlyAPICaller {

	private static let oauthAuthorizationGrantScope = "https://cloud.feedly.com/subscriptions"

	public static func oauthAuthorizationCodeGrantRequest(secretsProvider: SecretsProvider) -> URLRequest {
		let client = API.cloud.oauthAuthorizationClient(secretsProvider: secretsProvider)
		let authorizationRequest = OAuthAuthorizationRequest(clientID: client.id,
															 redirectURI: client.redirectURI,
															 scope: oauthAuthorizationGrantScope,
															 state: client.state)
		let baseURLComponents = API.cloud.baseUrlComponents
		return FeedlyAPICaller.authorizationCodeURLRequest(for: authorizationRequest, baseUrlComponents: baseURLComponents)
	}

	public static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse, transport: any Web.Transport, secretsProvider: any Secrets.SecretsProvider) async throws -> OAuthAuthorizationGrant {

		let client = API.cloud.oauthAuthorizationClient(secretsProvider: secretsProvider)
		let request = OAuthAccessTokenRequest(authorizationResponse: response,
											  scope: oauthAuthorizationGrantScope,
											  client: client)
		let caller = FeedlyAPICaller(transport: transport, api: .cloud, secretsProvider: secretsProvider)
		let response = try await caller.requestAccessToken(request)

		let accessToken = Credentials(type: .oauthAccessToken, username: response.id, secret: response.accessToken)
		let refreshToken: Credentials? = {
			guard let token = response.refreshToken else {
				return nil
			}
			return Credentials(type: .oauthRefreshToken, username: response.id, secret: token)
		}()

		let grant = OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: refreshToken)

		return grant
	}

	public func refreshAccessToken(with refreshToken: String, client: OAuthAuthorizationClient) async throws -> OAuthAuthorizationGrant {

		let request = OAuthRefreshAccessTokenRequest(refreshToken: refreshToken, scope: nil, client: client)
		let response = try await refreshAccessToken(request)

		let accessToken = Credentials(type: .oauthAccessToken, username: response.id, secret: response.accessToken)
		let refreshToken: Credentials? = {
			guard let token = response.refreshToken else {
				return nil
			}
			return Credentials(type: .oauthRefreshToken, username: response.id, secret: token)
		}()

		let grant = OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: refreshToken)
		return grant
	}
}

private extension FeedlyAPICaller {

	func urlRequest(path: String, method: String, includeJSONHeaders: Bool, includeOAuthToken: Bool) throws -> URLRequest {

		let url = apiURL(path)
		var request = URLRequest(url: url)

		request.httpMethod = method

		if includeJSONHeaders {
			addJSONHeaders(&request)
		}
		if includeOAuthToken {
			try addOAuthAccessToken(&request)
		}

		return request
	}

	func addJSONHeaders(_ request: inout URLRequest) {

		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
	}

	func addOAuthAccessToken(_ request: inout URLRequest) throws {

		guard let accessToken = credentials?.secret else {
			throw CredentialsError.incompleteCredentials
		}

		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
	}

	func apiURL(_ path: String) -> URL {

		var components = baseURLComponents
		components.path = path

		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}

		return url
	}

	func addObject<T: Encodable & Sendable>(_ object: T, keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys, to request: inout URLRequest) throws {

		let data = try JSONEncoder().encode(object)
		request.httpBody = data
	}
}
