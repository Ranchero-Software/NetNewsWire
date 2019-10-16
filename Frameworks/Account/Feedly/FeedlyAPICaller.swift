//
//  FeedlyAPICaller.swift
//  Account
//
//  Created by Kiel Gillard on 13/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class FeedlyAPICaller {
	
	enum API {
		case sandbox
		case cloud
		
		static var `default`: API {
			// https://developer.feedly.com/v3/developer/
			if let token = ProcessInfo.processInfo.environment["FEEDLY_DEV_ACCESS_TOKEN"], !token.isEmpty {
				return .cloud
			}
			
			return .sandbox
		}
		
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
	}
	
	private let transport: Transport
	private let baseUrlComponents: URLComponents
	
	init(transport: Transport, api: API) {
		self.transport = transport
		self.baseUrlComponents = api.baseUrlComponents
	}
	
	var credentials: Credentials?
	
	var server: String? {
		return baseUrlComponents.host
	}
	
	func getCollections(completionHandler: @escaping (Result<[FeedlyCollection], Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseUrlComponents
		components.path = "/v3/collections"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)

//		URLSession.shared.dataTask(with: request) { (data, response, error) in
//			print(String(data: data!, encoding: .utf8))
//		}.resume()
//
		transport.send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, collections)):
				if let response = collections {
					completionHandler(.success(response))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	func getStream(for resource: FeedlyResourceId, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool?, completionHandler: @escaping (Result<FeedlyStream, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		
		var components = baseUrlComponents
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
		
		transport.send(request: request, resultType: FeedlyStream.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, collections)):
				if let response = collections {
					completionHandler(.success(response))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	enum MarkAction {
		case read
		case unread
		case saved
		case unsaved
		
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
	
	private struct MarkerEntriesBody: Encodable {
		let type = "entries"
		var action: String
		var entryIds: [String]
	}
	
	func mark(_ articleIds: Set<String>, as action: MarkAction, completionHandler: @escaping (Result<Void, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseUrlComponents
		components.path = "/v3/markers"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		do {
			let body = MarkerEntriesBody(action: action.actionValue, entryIds: Array(articleIds))
			let encoder = JSONEncoder()
			let data = try encoder.encode(body)
			request.httpBody = data
		} catch {
			return DispatchQueue.main.async {
				completionHandler(.failure(error))
			}
		}
		
		transport.send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (httpResponse, _)):
				if httpResponse.statusCode == 200 {
					completionHandler(.success(()))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	func importOpml(_ opmlData: Data, completionHandler: @escaping (Result<Void, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseUrlComponents
		components.path = "/v3/opml"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("text/xml", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		request.httpBody = opmlData
		
		transport.send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (httpResponse, _)):
				if httpResponse.statusCode == 200 {
					completionHandler(.success(()))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	func createCollection(named label: String, completionHandler: @escaping (Result<FeedlyCollection, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseUrlComponents
		components.path = "/v3/collections"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		do {
			struct CreateCollectionBody: Encodable {
				var label: String
			}
			let encoder = JSONEncoder()
			let data = try encoder.encode(CreateCollectionBody(label: label))
			request.httpBody = data
		} catch {
			return DispatchQueue.main.async {
				completionHandler(.failure(error))
			}
		}
		
		transport.send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (httpResponse, collections)):
				if httpResponse.statusCode == 200, let collection = collections?.first {
					completionHandler(.success(collection))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	func renameCollection(with id: String, to name: String, completionHandler: @escaping (Result<FeedlyCollection, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		var components = baseUrlComponents
		components.path = "/v3/collections"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		do {
			struct RenameCollectionBody: Encodable {
				var id: String
				var label: String
			}
			let encoder = JSONEncoder()
			let data = try encoder.encode(RenameCollectionBody(id: id, label: name))
			request.httpBody = data
		} catch {
			return DispatchQueue.main.async {
				completionHandler(.failure(error))
			}
		}
		
		transport.send(request: request, resultType: [FeedlyCollection].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (httpResponse, collections)):
				if httpResponse.statusCode == 200, let collection = collections?.first {
					completionHandler(.success(collection))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	private func encodeForURLPath(_ pathComponent: String) -> String? {
		return pathComponent.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
	}
	
	func deleteCollection(with id: String, completionHandler: @escaping (Result<Void, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}
		guard let encodedId = encodeForURLPath(id) else {
			return DispatchQueue.main.async {
				completionHandler(.failure(FeedbinAccountDelegateError.invalidParameter))
			}
		}
		var components = baseUrlComponents
		components.percentEncodedPath = "/v3/collections/\(encodedId)"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "DELETE"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		transport.send(request: request, resultType: String.self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (httpResponse, _)):
				if httpResponse.statusCode == 200 {
					completionHandler(.success(()))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	func addFeed(with feedId: FeedlyFeedResourceId, title: String? = nil, toCollectionWith collectionId: String, completionHandler: @escaping (Result<[FeedlyFeed], Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}

		guard let encodedId = encodeForURLPath(collectionId) else {
			return DispatchQueue.main.async {
				completionHandler(.failure(FeedbinAccountDelegateError.invalidParameter))
			}
		}
		var components = baseUrlComponents
		components.percentEncodedPath = "/v3/collections/\(encodedId)/feeds"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "PUT"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		do {
			struct AddFeedBody: Encodable {
				var id: String
				var title: String?
			}
			let encoder = JSONEncoder()
			let data = try encoder.encode(AddFeedBody(id: feedId.id, title: title))
			request.httpBody = data
		} catch {
			return DispatchQueue.main.async {
				completionHandler(.failure(error))
			}
		}
		
		transport.send(request: request, resultType: [FeedlyFeed].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(_, let collectionFeeds):
				if let feeds = collectionFeeds {
					completionHandler(.success(feeds))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
	
	func removeFeed(_ feedId: String, fromCollectionWith collectionId: String, completionHandler: @escaping (Result<Void, Error>) -> ()) {
		guard let accessToken = credentials?.secret else {
			return DispatchQueue.main.async {
				completionHandler(.failure(CredentialsError.incompleteCredentials))
			}
		}

		guard let encodedCollectionId = encodeForURLPath(collectionId), let encodedFeedId = encodeForURLPath(feedId) else {
			return DispatchQueue.main.async {
				completionHandler(.failure(FeedbinAccountDelegateError.invalidParameter))
			}
		}
		var components = baseUrlComponents
		components.percentEncodedPath = "/v3/collections/\(encodedCollectionId)/feeds/\(encodedFeedId)"
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "DELETE"
		request.addValue("application/json", forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		request.addValue("OAuth \(accessToken)", forHTTPHeaderField: HTTPRequestHeader.authorization)
		
		transport.send(request: request, resultType: [FeedlyFeed].self, dateDecoding: .millisecondsSince1970, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let httpResponse, _):
				if httpResponse.statusCode == 200 {
					completionHandler(.success(()))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
}

extension FeedlyAPICaller: OAuthAuthorizationCodeGrantRequesting {
	
	static func authorizationCodeUrlRequest(for request: OAuthAuthorizationRequest) -> URLRequest {
		let api = API.default
		var components = api.baseUrlComponents
		components.path = "/v3/auth/auth"
		components.queryItems = request.queryItems
		
		guard let url = components.url else {
			fatalError("\(components) does not produce a valid URL.")
		}
		
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
		
		return request
	}
	
	typealias AccessTokenResponse = FeedlyOAuthAccessTokenResponse
	
	func requestAccessToken(_ authorizationRequest: OAuthAccessTokenRequest, completionHandler: @escaping (Result<FeedlyOAuthAccessTokenResponse, Error>) -> ()) {
		var components = baseUrlComponents
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
				completionHandler(.failure(error))
			}
			return
		}
		
		transport.send(request: request, resultType: AccessTokenResponse.self, keyDecoding: .convertFromSnakeCase) { result in
			switch result {
			case .success(let (_, tokenResponse)):
				if let response = tokenResponse {
					completionHandler(.success(response))
				} else {
					completionHandler(.failure(URLError(.cannotDecodeContentData)))
				}
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
}
