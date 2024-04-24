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
import Feedly

protocol FeedlyAPICallerDelegate: AnyObject {
	/// Implemented by the `FeedlyAccountDelegate` reauthorize the client with a fresh OAuth token so the client can retry the unauthorized request.
	/// Pass `true` to the completion handler if the failing request should be retried with a fresh token or `false` if the unauthorized request should complete with the original failure error.
	@MainActor func reauthorizeFeedlyAPICaller(_ caller: FeedlyAPICaller, completionHandler: @escaping (Bool) -> ())
}

@MainActor final class FeedlyAPICaller {

	enum API {
		case sandbox
		case cloud
		
		var baseUrlComponents: URLComponents {
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
		
		func oauthAuthorizationClient(secretsProvider: SecretsProvider) -> OAuthAuthorizationClient {
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
	
	init(transport: Transport, api: API, secretsProvider: SecretsProvider) {
		self.transport = transport
		self.baseURLComponents = api.baseUrlComponents
		self.secretsProvider = secretsProvider

		var urlHostAllowed = CharacterSet.urlHostAllowed
		urlHostAllowed.remove("+")
		uriComponentAllowed = urlHostAllowed
	}
	
	weak var delegate: FeedlyAPICallerDelegate?
	
	var credentials: Credentials?
	
	var server: String? {
		return baseURLComponents.host
	}
	
	func cancelAll() {
		transport.cancelAll()
	}
	
	private var isSuspended = false
	
	/// Cancels all pending requests rejects any that come in later
	func suspend() {
		transport.cancelAll()
		isSuspended = true
	}
	
	func resume() {
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

	private func send<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys, completion: @escaping (Result<(HTTPURLResponse, R?), Error>) -> Void) {
		transport.send(request: request, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding) { [weak self] result in
			
			MainActor.assumeIsolated {
				
				switch result {
				case .success:
					completion(result)
				case .failure(let error):
					switch error {
					case TransportError.httpError(let statusCode) where statusCode == 401:
						
						assert(self == nil ? true : self?.delegate != nil, "Check the delegate is set to \(FeedlyAccountDelegate.self).")
						
						guard let self = self, let delegate = self.delegate else {
							completion(result)
							return
						}
						
						/// Capture the credentials before the reauthorization to check for a change.
						let credentialsBefore = self.credentials
						
						delegate.reauthorizeFeedlyAPICaller(self) { [weak self] isReauthorizedAndShouldRetry in
							assert(Thread.isMainThread)
							
							guard isReauthorizedAndShouldRetry, let self = self else {
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
						}
					default:
						completion(result)
					}
				}
			}
		}
	}
	
	func importOPML(_ opmlData: Data) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/opml", method: HTTPMethod.post, includeJSONHeaders: false, includeOauthToken: true)
		request.addValue("text/xml", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.acceptType)
		request.httpBody = opmlData

		let (httpResponse, _) = try await send(request: request, resultType: String.self)
		if httpResponse.statusCode != HTTPResponseCode.OK {
			throw URLError(.cannotDecodeContentData)
		}
	}
	
	func createCollection(named label: String) async throws -> FeedlyCollection {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/collections", method: HTTPMethod.post, includeJSONHeaders: true, includeOauthToken: true)

		struct CreateCollectionBody: Encodable {
			var label: String
		}
		let encoder = JSONEncoder()
		let data = try encoder.encode(CreateCollectionBody(label: label))
		request.httpBody = data

		let (httpResponse, collections) = try await send(request: request, resultType: [FeedlyCollection].self)

		guard let collection = collections?.first, httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
		return collection
	}

	func renameCollection(with id: String, to name: String) async throws -> FeedlyCollection {

		guard !isSuspended else { throw TransportError.suspended }

		var request = try urlRequest(path: "/v3/collections", method: HTTPMethod.post, includeJSONHeaders: true, includeOauthToken: true)

		struct RenameCollectionBody: Encodable {
			var id: String
			var label: String
		}
		let encoder = JSONEncoder()
		let data = try encoder.encode(RenameCollectionBody(id: id, label: name))
		request.httpBody = data

		let (httpResponse, collections) = try await send(request: request, resultType: [FeedlyCollection].self)

		guard let collection = collections?.first, httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
		return collection
	}

	private func encodeForURLPath(_ pathComponent: String) -> String? {
		return pathComponent.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed)
	}
	
	func deleteCollection(with id: String) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		guard let encodedID = encodeForURLPath(id) else {
			throw FeedlyAccountDelegateError.unexpectedResourceID(id)
		}
		let request = try urlRequest(path: "/v3/collections/\(encodedID)", method: HTTPMethod.delete, includeJSONHeaders: true, includeOauthToken: true)

		let (httpResponse, _) = try await send(request: request, resultType: Optional<FeedlyCollection>.self)

		guard httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
	}
	
	func removeFeed(_ feedId: String, fromCollectionWith collectionID: String) async throws {

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
		try addOauthAccessToken(&request)

		struct RemovableFeed: Encodable {
			let id: String
		}
		let encoder = JSONEncoder()
		let data = try encoder.encode([RemovableFeed(id: feedId)])
		request.httpBody = data

        // `resultType` is optional because the Feedly API has gone from returning an array of removed feeds to returning `null`.
        // https://developer.feedly.com/v3/collections/#remove-multiple-feeds-from-a-personal-collection
		let (httpResponse, _) = try await send(request: request, resultType: Optional<[FeedlyFeed]>.self)

		guard httpResponse.statusCode == HTTPResponseCode.OK else {
			throw URLError(.cannotDecodeContentData)
		}
	}
}

extension FeedlyAPICaller: FeedlyAddFeedToCollectionService {
	
	@MainActor func addFeed(with feedID: FeedlyFeedResourceID, title: String? = nil, toCollectionWith collectionID: String) async throws -> [FeedlyFeed] {

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
		try addOauthAccessToken(&request)

		struct AddFeedBody: Encodable {
			var id: String
			var title: String?
		}
		let encoder = JSONEncoder()
		let data = try encoder.encode(AddFeedBody(id: feedID.id, title: title))
		request.httpBody = data

		let (_, collectionFeeds) = try await send(request: request, resultType: [FeedlyFeed].self)
		guard let collectionFeeds else {
			throw URLError(.cannotDecodeContentData)
		}

		return collectionFeeds
	}
}

extension FeedlyAPICaller: OAuthAuthorizationCodeGrantRequesting {
	
	static func authorizationCodeUrlRequest(for request: OAuthAuthorizationRequest, baseUrlComponents: URLComponents) -> URLRequest {
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
	
	typealias AccessTokenResponse = FeedlyOAuthAccessTokenResponse
	
	func requestAccessToken(_ authorizationRequest: OAuthAccessTokenRequest, completion: @escaping (Result<FeedlyOAuthAccessTokenResponse, Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		var components = baseURLComponents
		components.path = "/v3/auth/token"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		do {
			let encoder = JSONEncoder()
			encoder.keyEncodingStrategy = .convertToSnakeCase
			request.httpBody = try encoder.encode(authorizationRequest)
		} catch {
			DispatchQueue.main.async {
				completion(.failure(error))
			}
			return
		}
		
		send(request: request, resultType: AccessTokenResponse.self, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, tokenResponse)):
				if let response = tokenResponse {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: OAuthAcessTokenRefreshRequesting {
		
	func refreshAccessToken(_ refreshRequest: OAuthRefreshAccessTokenRequest, completion: @escaping (Result<FeedlyOAuthAccessTokenResponse, Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		var components = baseURLComponents
		components.path = "/v3/auth/token"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		do {
			let encoder = JSONEncoder()
			encoder.keyEncodingStrategy = .convertToSnakeCase
			request.httpBody = try encoder.encode(refreshRequest)
		} catch {
			DispatchQueue.main.async {
				completion(.failure(error))
			}
			return
		}
		
		send(request: request, resultType: AccessTokenResponse.self, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, tokenResponse)):
				if let response = tokenResponse {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlyGetCollectionsService {
	
	func getCollections(completion: @escaping @Sendable (Result<[FeedlyCollection], Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completion(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseURLComponents
		components.path = "/v3/collections"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, collections)):
				if let response = collections {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlyGetStreamContentsService {
	
	@MainActor func getStreamContents(for resource: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStream, Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completion(.failure(CredentialsError.incompleteCredentials))
			}
		}
		
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
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		send(request: request, resultType: FeedlyStream.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, collections)):
				if let response = collections {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlyGetStreamIDsService {
	
	@MainActor func getStreamIDs(for resource: FeedlyResourceID, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStreamIDs, Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completion(.failure(CredentialsError.incompleteCredentials))
			}
		}
		
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
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		send(request: request, resultType: FeedlyStreamIDs.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, collections)):
				if let response = collections {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlyGetEntriesService {
	
	func getEntries(for ids: Set<String>, completion: @escaping (Result<[FeedlyEntry], Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completion(.failure(CredentialsError.incompleteCredentials))
			}
		}
		
		var components = baseURLComponents
		components.path = "/v3/entries/.mget"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		
		do {
			let body = Array(ids)
			let encoder = JSONEncoder()
			let data = try encoder.encode(body)
			request.httpBody = data
		} catch {
			return DispatchQueue.main.async {
				completion(.failure(error))
			}
		}
		
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		send(request: request, resultType: [FeedlyEntry].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, entries)):
				if let response = entries {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlyMarkArticlesService {
	
	private struct MarkerEntriesBody: Encodable {
		let type = "entries"
		var action: String
		var entryIDs: [String]
	}
	
	func mark(_ articleIDs: Set<String>, as action: FeedlyMarkAction, completion: @escaping @Sendable (Result<Void, Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completion(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseURLComponents
		components.path = "/v3/markers"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		let articleIDChunks = Array(articleIDs).chunked(into: 300)
		let dispatchGroup = DispatchGroup()
		var groupError: Error? = nil

		for articleIDChunk in articleIDChunks {

			var request = URLRequest(url: url)
			request.httpMethod = "POST"
			request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
			request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
			request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
			
			do {
				let body = MarkerEntriesBody(action: action.actionValue, entryIDs: Array(articleIDChunk))
				let encoder = JSONEncoder()
				let data = try encoder.encode(body)
				request.httpBody = data
			} catch {
				return DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
			
			dispatchGroup.enter()
			send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
				switch result {
				case .success(let (httpResponse, _)):
					if httpResponse.statusCode != 200 {
						groupError = URLError(.cannotDecodeContentData)
					}
				case .failure(let error):
					groupError = error
				}
				dispatchGroup.leave()
			}
		}
		
		dispatchGroup.notify(queue: .main) {
			if let groupError = groupError {
				completion(.failure(groupError))
			} else {
				completion(.success(()))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlySearchService {
	
	func getFeeds(for query: String, count: Int, locale: String, completion: @escaping (Result<FeedlyFeedsSearchResponse, Error>) -> ()) {
		
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
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
		request.httpMethod = "GET"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		send(request: request, resultType: FeedlyFeedsSearchResponse.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, searchResponse)):
				if let response = searchResponse {
					completion(.success(response))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: FeedlyLogoutService {
	
	func logout(completion: @escaping (Result<Void, Error>) -> ()) {
		guard !isSuspended else {
			return DispatchQueue.main.async {
				completion(.failure(TransportError.suspended))
			}
		}
		
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completion(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseURLComponents
		components.path = "/v3/auth/logout"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (httpResponse, _)):
				if httpResponse.statusCode == 200 {
					completion(.success(()))
				} else {
					completion(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}

private extension FeedlyAPICaller {

	func urlRequest(path: String, method: String, includeJSONHeaders: Bool, includeOauthToken: Bool) throws -> URLRequest {

		let url = apiURL(path)
		var request = URLRequest(url: url)

		request.httpMethod = method

		if includeJSONHeaders {
			addJSONHeaders(&request)
		}
		if includeOauthToken {
			try addOauthAccessToken(&request)
		}

		return request
	}

	func addJSONHeaders(_ request: inout URLRequest) {

		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
	}

	func addOauthAccessToken(_ request: inout URLRequest) throws {

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
}
