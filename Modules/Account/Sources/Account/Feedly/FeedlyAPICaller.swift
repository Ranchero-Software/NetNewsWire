//
//  FeedlyAPICaller.swift
//  Account
//
//  Created by Kiel Gillard on 13/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb
import Secrets

@MainActor protocol FeedlyAPICallerDelegate: AnyObject {

	/// Refresh the OAuth credentials so the caller can retry the failed request.
	/// Returns `true` if the caller should retry the request with the new token,
	/// or `false` if the original 401 failure should be surfaced.
	func reauthorizeFeedlyAPICaller() async -> Bool
}

enum FeedlyMarkAction: String, Sendable {
	case read
	case unread
	case saved
	case unsaved

	/// Paired with the `action` key in POST requests to the markers API.
	/// See https://developer.feedly.com/v3/markers/#mark-one-or-multiple-articles-as-read
	var actionValue: String {
		switch self {
		case .read:
			return "markAsRead"
		case .unread:
			return "keepUnread"
		case .saved:
			return "markAsSaved"
		case .unsaved:
			return "markAsUnsaved"
		}
	}
}

@MainActor final class FeedlyAPICaller {

	enum API: Sendable {
		case sandbox
		case cloud

		var baseURLComponents: URLComponents {
			var components = URLComponents()
			components.scheme = "https"
			switch self {
			case .sandbox:
				// https://groups.google.com/forum/#!topic/feedly-cloud/WwQWMgDmOuw
				components.host = "sandbox7.feedly.com"
			case .cloud:
				// https://developer.feedly.com/cloud/
				components.host = "cloud.feedly.com"
			}
			return components
		}

		var oauthAuthorizationClient: OAuthAuthorizationClient {
			switch self {
			case .sandbox:
				return .feedlySandboxClient
			case .cloud:
				return .feedlyCloudClient
			}
		}
	}

	weak var delegate: FeedlyAPICallerDelegate?
	var credentials: Credentials?

	var server: String? {
		return baseURLComponents.host
	}

	private let session = URLSession.webservice
	private let baseURLComponents: URLComponents
	private let uriComponentAllowed: CharacterSet
	private var isSuspended = false

	private static let streamContentsCount = 1000
	private static let streamIDsCount = 10000

	init(api: API) {
		self.baseURLComponents = api.baseURLComponents

		// Encode against a path-safe set. urlHostAllowed permits characters like [ and ]
		// that are illegal in a path, which makes the percentEncodedPath setter trap.
		var pathComponentAllowed = CharacterSet.urlPathAllowed
		pathComponentAllowed.remove("/")
		pathComponentAllowed.remove("+")
		self.uriComponentAllowed = pathComponentAllowed
	}

	func cancelAll() {
		session.cancelAll()
	}

	/// Cancels all pending requests and rejects any that come in later.
	func suspend() {
		session.cancelAll()
		isSuspended = true
	}

	func resume() {
		isSuspended = false
	}
}

// MARK: - Collections

extension FeedlyAPICaller {

	func getCollections() async throws -> [FeedlyCollection] {
		let request = try makeAuthorizedRequest(path: "/v3/collections")
		let (_, collections) = try await send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard let collections else {
			throw URLError(.cannotDecodeContentData)
		}
		return collections
	}

	func createCollection(named label: String) async throws -> FeedlyCollection {
		struct CreateCollectionBody: Encodable {
			var label: String
		}

		var request = try makeAuthorizedRequest(path: "/v3/collections", method: HTTPMethod.post)
		request.httpBody = try JSONEncoder().encode(CreateCollectionBody(label: label))

		let (httpResponse, collections) = try await send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200, let collection = collections?.first else {
			throw URLError(.cannotDecodeContentData)
		}
		return collection
	}

	func renameCollection(with id: String, to name: String) async throws -> FeedlyCollection {
		struct RenameCollectionBody: Encodable {
			var id: String
			var label: String
		}

		var request = try makeAuthorizedRequest(path: "/v3/collections", method: HTTPMethod.post)
		request.httpBody = try JSONEncoder().encode(RenameCollectionBody(id: id, label: name))

		let (httpResponse, collections) = try await send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200, let collection = collections?.first else {
			throw URLError(.cannotDecodeContentData)
		}
		return collection
	}

	func deleteCollection(with id: String) async throws {
		guard let encodedID = encodeForURLPath(id) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(id)
		}
		let request = try makeAuthorizedRequest(percentEncodedPath: "/v3/collections/\(encodedID)", method: HTTPMethod.delete)

		let (httpResponse, _) = try await send(request: request, resultType: Optional<FeedlyCollection>.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200 else {
			throw URLError(.cannotDecodeContentData)
		}
	}

	func addFeed(with feedID: FeedlyFeedResourceID, title: String? = nil, toCollectionWith collectionID: String) async throws -> [FeedlyFeed] {
		struct AddFeedBody: Encodable {
			var id: String
			var title: String?
		}

		guard let encodedID = encodeForURLPath(collectionID) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(collectionID)
		}
		var request = try makeAuthorizedRequest(percentEncodedPath: "/v3/collections/\(encodedID)/feeds", method: HTTPMethod.put)
		request.httpBody = try JSONEncoder().encode(AddFeedBody(id: feedID.id, title: title))

		let (_, feeds) = try await send(request: request, resultType: [FeedlyFeed].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard let feeds else {
			throw URLError(.cannotDecodeContentData)
		}
		return feeds
	}

	func removeFeed(_ feedID: String, fromCollectionWith collectionID: String) async throws {
		struct RemovableFeed: Encodable {
			let id: String
		}

		guard let encodedCollectionID = encodeForURLPath(collectionID) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(collectionID)
		}
		var request = try makeAuthorizedRequest(percentEncodedPath: "/v3/collections/\(encodedCollectionID)/feeds/.mdelete", method: HTTPMethod.delete)
		request.httpBody = try JSONEncoder().encode([RemovableFeed(id: feedID)])

		// `resultType` is optional because the Feedly API has gone from returning an array of removed feeds to returning `null`.
		// https://developer.feedly.com/v3/collections/#remove-multiple-feeds-from-a-personal-collection
		let (httpResponse, _) = try await send(request: request, resultType: Optional<[FeedlyFeed]>.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200 else {
			throw URLError(.cannotDecodeContentData)
		}
	}
}

// MARK: - Streams

extension FeedlyAPICaller {

	func getStreamContents(for resource: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStream {
		var queryItems = [URLQueryItem]()

		if let date = newerThan {
			let value = String(Int(date.timeIntervalSince1970 * 1000))
			queryItems.append(URLQueryItem(name: "newerThan", value: value))
		}
		if let flag = unreadOnly {
			queryItems.append(URLQueryItem(name: "unreadOnly", value: flag ? "true" : "false"))
		}
		if let value = continuation, !value.isEmpty {
			queryItems.append(URLQueryItem(name: "continuation", value: value))
		}
		queryItems.append(URLQueryItem(name: "count", value: String(Self.streamContentsCount)))
		queryItems.append(URLQueryItem(name: "streamId", value: resource.id))

		let request = try makeAuthorizedRequest(path: "/v3/streams/contents", queryItems: queryItems)
		let (_, stream) = try await send(request: request, resultType: FeedlyStream.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard let stream else {
			throw URLError(.cannotDecodeContentData)
		}
		return stream
	}

	func getStreamIDs(for resource: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool?) async throws -> FeedlyStreamIDs {
		var queryItems = [URLQueryItem]()

		if let date = newerThan {
			let value = String(Int(date.timeIntervalSince1970 * 1000))
			queryItems.append(URLQueryItem(name: "newerThan", value: value))
		}
		if let flag = unreadOnly {
			queryItems.append(URLQueryItem(name: "unreadOnly", value: flag ? "true" : "false"))
		}
		if let value = continuation, !value.isEmpty {
			queryItems.append(URLQueryItem(name: "continuation", value: value))
		}
		queryItems.append(URLQueryItem(name: "count", value: String(Self.streamIDsCount)))
		queryItems.append(URLQueryItem(name: "streamId", value: resource.id))

		let request = try makeAuthorizedRequest(path: "/v3/streams/ids", queryItems: queryItems)
		let (_, streamIDs) = try await send(request: request, resultType: FeedlyStreamIDs.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard let streamIDs else {
			throw URLError(.cannotDecodeContentData)
		}
		return streamIDs
	}
}

// MARK: - Entries and Markers

extension FeedlyAPICaller {

	func getEntries(for ids: Set<String>) async throws -> [FeedlyEntry] {
		var request = try makeAuthorizedRequest(path: "/v3/entries/.mget", method: HTTPMethod.post)
		request.httpBody = try JSONEncoder().encode(Array(ids))

		let (_, entries) = try await send(request: request, resultType: [FeedlyEntry].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard let entries else {
			throw URLError(.cannotDecodeContentData)
		}
		return entries
	}

	/// Marks one batch of article IDs. The caller is responsible for chunking to
	/// stay within the Feedly markers limit (see `FeedlyAccountDelegate.markChunkSize`).
	func mark(_ articleIDs: Set<String>, as action: FeedlyMarkAction) async throws {
		struct MarkerEntriesBody: Encodable {
			let type = "entries"
			var action: String
			var entryIds: [String]
		}

		var request = try makeAuthorizedRequest(path: "/v3/markers", method: HTTPMethod.post)
		request.httpBody = try JSONEncoder().encode(MarkerEntriesBody(action: action.actionValue, entryIds: Array(articleIDs)))

		let (httpResponse, _) = try await send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200 else {
			throw URLError(.cannotDecodeContentData)
		}
	}
}

// MARK: - OPML

extension FeedlyAPICaller {

	func importOPML(_ opmlData: Data) async throws {
		guard !isSuspended else {
			throw WebserviceError.suspended
		}
		guard let accessToken = credentials?.secret else {
			throw CredentialsError.missingAccessToken
		}

		var components = baseURLComponents
		components.path = "/v3/opml"
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}

		var request = URLRequest(url: url)
		request.httpMethod = HTTPMethod.post
		request.addValue("text/xml", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		request.httpBody = opmlData

		let (httpResponse, _) = try await send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200 else {
			throw URLError(.cannotDecodeContentData)
		}
	}
}

// MARK: - Search

extension FeedlyAPICaller {

	func getFeeds(for query: String, count: Int, locale: String) async throws -> FeedlyFeedsSearchResponse {
		guard !isSuspended else {
			throw WebserviceError.suspended
		}

		var components = baseURLComponents
		components.path = "/v3/search/feeds"
		components.queryItems = [
			URLQueryItem(name: "query", value: query),
			URLQueryItem(name: "count", value: String(count)),
			URLQueryItem(name: "locale", value: locale)
		]
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}

		var request = URLRequest(url: url)
		request.httpMethod = HTTPMethod.get
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")

		let (_, response) = try await send(request: request, resultType: FeedlyFeedsSearchResponse.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard let response else {
			throw URLError(.cannotDecodeContentData)
		}
		return response
	}
}

// MARK: - OAuth

extension FeedlyAPICaller {

	/// Build the URL request that authorizes a Feedly account.
	/// Loaded by a web view to ask the user to consent to the client having access to their account.
	static func authorizationCodeURLRequest(for request: OAuthAuthorizationRequest, baseURLComponents: URLComponents) -> URLRequest {
		var components = baseURLComponents
		components.path = "/v3/auth/auth"
		components.queryItems = request.queryItems

		guard let url = components.url else {
			assert(components.scheme != nil)
			assert(components.host != nil)
			fatalError("\(components) does not produce a valid URL.")
		}

		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		return urlRequest
	}

	func requestAccessToken(_ authorizationRequest: OAuthAccessTokenRequest) async throws -> FeedlyOAuthAccessTokenResponse {
		return try await postOAuthTokenRequest(body: authorizationRequest)
	}

	func refreshAccessToken(_ refreshRequest: OAuthRefreshAccessTokenRequest) async throws -> FeedlyOAuthAccessTokenResponse {
		return try await postOAuthTokenRequest(body: refreshRequest)
	}
}

// MARK: - Logout

extension FeedlyAPICaller {

	func logout() async throws {
		let request = try makeAuthorizedRequest(path: "/v3/auth/logout", method: HTTPMethod.post)
		let (httpResponse, _) = try await send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase)
		guard httpResponse.statusCode == 200 else {
			throw URLError(.cannotDecodeContentData)
		}
	}
}

// MARK: - Send and 401 Retry

private extension FeedlyAPICaller {

	func send<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		do {
			return try await session.send(request: request, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
		} catch WebserviceError.httpError(let status) where status == 401 {
			return try await retryAfterReauthorization(request: request, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
		}
	}

	func retryAfterReauthorization<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy, keyDecoding: JSONDecoder.KeyDecodingStrategy) async throws -> (HTTPURLResponse, R?) {

		guard let delegate else {
			assertionFailure("Check the delegate is set to \(FeedlyAccountDelegate.self).")
			throw WebserviceError.httpError(status: 401)
		}

		// Capture credentials before reauthorization so we can detect that they actually changed.
		let credentialsBefore = credentials

		let didReauthorize = await delegate.reauthorizeFeedlyAPICaller()
		guard didReauthorize else {
			throw WebserviceError.httpError(status: 401)
		}

		// Catches an infinitely recursive attempt to refresh.
		guard let accessToken = credentials?.secret, accessToken != credentialsBefore?.secret else {
			assertionFailure("Could not update the request with a new OAuth token. Did \(String(describing: delegate)) set them on \(self)?")
			throw WebserviceError.httpError(status: 401)
		}

		var reauthorizedRequest = request
		reauthorizedRequest.setValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)

		return try await send(request: reauthorizedRequest, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
	}
}

// MARK: - Request Builders

private extension FeedlyAPICaller {

	func makeAuthorizedRequest(path: String, queryItems: [URLQueryItem]? = nil, method: String = HTTPMethod.get) throws -> URLRequest {
		try ensureReadyForRequest()
		let accessToken = try requireAccessToken()

		var components = baseURLComponents
		components.path = path
		if let queryItems {
			components.queryItems = queryItems
		}
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}

		return makeJSONRequest(url: url, method: method, accessToken: accessToken)
	}

	func makeAuthorizedRequest(percentEncodedPath: String, method: String = HTTPMethod.get) throws -> URLRequest {
		try ensureReadyForRequest()
		let accessToken = try requireAccessToken()

		var components = baseURLComponents
		components.percentEncodedPath = percentEncodedPath
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}

		return makeJSONRequest(url: url, method: method, accessToken: accessToken)
	}

	func makeJSONRequest(url: URL, method: String, accessToken: String) -> URLRequest {
		var request = URLRequest(url: url)
		request.httpMethod = method
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		return request
	}

	func ensureReadyForRequest() throws {
		if isSuspended {
			throw WebserviceError.suspended
		}
	}

	func requireAccessToken() throws -> String {
		guard let secret = credentials?.secret else {
			throw CredentialsError.missingAccessToken
		}
		return secret
	}

	func encodeForURLPath(_ pathComponent: String) -> String? {
		return pathComponent.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed)
	}

	func postOAuthTokenRequest<T: Encodable>(body: T) async throws -> FeedlyOAuthAccessTokenResponse {
		guard !isSuspended else {
			throw WebserviceError.suspended
		}

		var components = baseURLComponents
		components.path = "/v3/auth/token"
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}

		var request = URLRequest(url: url)
		request.httpMethod = HTTPMethod.post
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")

		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		request.httpBody = try encoder.encode(body)

		let (_, response) = try await send(request: request, resultType: FeedlyOAuthAccessTokenResponse.self, keyDecoding: .convertFromSnakeCase)
		guard let response else {
			throw URLError(.cannotDecodeContentData)
		}
		return response
	}
}
