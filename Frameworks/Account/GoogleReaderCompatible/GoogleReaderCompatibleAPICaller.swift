//
//  GoogleReaderCompatibleAPICaller.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

// GoogleReaderCompatible currently has a maximum of 250 requests per second.  If you begin to receive
// HTTP Response Codes of 403, you have exceeded this limit.  Wait 5 minutes and your
// IP address will become unblocked and you can use the service again.

import Foundation
import RSWeb

enum CreateGoogleReaderSubscriptionResult {
	case created(GoogleReaderCompatibleSubscription)
	case multipleChoice([GoogleReaderCompatibleSubscriptionChoice])
	case alreadySubscribed
	case notFound
}

final class GoogleReaderCompatibleAPICaller: NSObject {
	
	struct ConditionalGetKeys {
		static let subscriptions = "subscriptions"
		static let tags = "tags"
		static let taggings = "taggings"
		static let icons = "icons"
		static let unreadEntries = "unreadEntries"
		static let starredEntries = "starredEntries"
	}
	
	private let GoogleReaderCompatibleBaseURL = URL(string: "https://api.GoogleReaderCompatible.com/v2/")!
	private var transport: Transport!
	
	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?

	var server: String? {
		get {
			return APIBaseURL?.host
		}
	}
	
	private var APIBaseURL: URL? {
		get {
			guard let accountMetadata = accountMetadata else {
				return nil
			}
	
			return accountMetadata.endpointURL
		}
	}
	
	
	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func validateCredentials(endpoint: URL, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		guard let credentials = credentials else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		guard case .googleBasicLogin(let username, _) = credentials else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let request = URLRequest(url: endpoint.appendingPathComponent("/accounts/ClientLogin"), credentials: credentials)

		transport.send(request: request) { result in
			switch result {
			case .success(let (_, data)):
				guard let resultData = data else {
					completion(.failure(TransportError.noData))
					break
				}
				
				// Convert the return data to UTF8 and then parse out the Auth token
				guard let rawData = String(data: resultData, encoding: .utf8) else {
					completion(.failure(TransportError.noData))
					break
				}
				
				var authData: [String: String] = [:]
				rawData.split(separator: "\n").forEach({ (line: Substring) in
					let items = line.split(separator: "=").map{String($0)}
					authData[items[0]] = items[1]
				})
				
				guard let authString = authData["Auth"] else {
					completion(.failure(CredentialsError.incompleteCredentials))
					break
				}
				
				// Save Auth Token for later use
				self.credentials = .googleAuthLogin(username: username, apiKey: authString)
				
				completion(.success(self.credentials))
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func importOPML(opmlData: Data, completion: @escaping (Result<GoogleReaderCompatibleImportResult, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("imports.json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		transport.send(request: request, method: HTTPMethod.post, payload: opmlData) { result in
			
			switch result {
			case .success(let (_, data)):
				
				guard let resultData = data else {
					completion(.failure(TransportError.noData))
					break
				}
				
				do {
					let result = try JSONDecoder().decode(GoogleReaderCompatibleImportResult.self, from: resultData)
					completion(.success(result))
				} catch {
					completion(.failure(error))
				}

			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func retrieveOPMLImportResult(importID: Int, completion: @escaping (Result<GoogleReaderCompatibleImportResult?, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("imports/\(importID).json")
		let request = URLRequest(url: callURL, credentials: credentials)
		
		transport.send(request: request, resultType: GoogleReaderCompatibleImportResult.self) { result in
			
			switch result {
			case .success(let (_, importResult)):
				completion(.success(importResult))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func retrieveTags(completion: @escaping (Result<[GoogleReaderCompatibleTag]?, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		// Add query string for getting JSON (probably should break this out as I will be doing it a lot)
		guard var components = URLComponents(url: baseURL.appendingPathComponent("/reader/api/0/tag/list"), resolvingAgainstBaseURL: false) else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		components.queryItems = [
			URLQueryItem(name: "output", value: "json")
		]

		guard let callURL = components.url else {
			completion(.failure(TransportError.noURL))
			return
		}

		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.tags]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: GoogleReaderCompatibleTagContainer.self) { result in
			
			switch result {
			case .success(let (response, wrapper)):
				self.storeConditionalGet(key: ConditionalGetKeys.tags, headers: response.allHeaderFields)
				completion(.success(wrapper?.tags))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func renameTag(oldName: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("tags.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleRenameTag(oldName: oldName, newName: newName)
		transport.send(request: request, method: HTTPMethod.post, payload: payload, completion: completion)
	}
	
	func deleteTag(name: String, completion: @escaping (Result<[GoogleReaderCompatibleTagging]?, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("tags.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleDeleteTag(name: name)
		
		transport.send(request: request, method: HTTPMethod.delete, payload: payload, resultType: [GoogleReaderCompatibleTagging].self) { result in

			switch result {
			case .success(let (_, taggings)):
				completion(.success(taggings))
			case .failure(let error):
				completion(.failure(error))
			}

		}
		
	}
	
	func retrieveSubscriptions(completion: @escaping (Result<[GoogleReaderCompatibleSubscription]?, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		// Add query string for getting JSON (probably should break this out as I will be doing it a lot)
		guard var components = URLComponents(url: baseURL.appendingPathComponent("/reader/api/0/subscription/list"), resolvingAgainstBaseURL: false) else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		components.queryItems = [
			URLQueryItem(name: "output", value: "json")
		]
		
		guard let callURL = components.url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.subscriptions]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: GoogleReaderCompatibleSubscriptionContainer.self) { result in
			
			switch result {
			case .success(let (response, container)):
				self.storeConditionalGet(key: ConditionalGetKeys.subscriptions, headers: response.allHeaderFields)
				completion(.success(container?.subscriptions))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func createSubscription(url: String, completion: @escaping (Result<CreateGoogleReaderSubscriptionResult, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("subscriptions.json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)
		
		let payload: Data
		do {
			payload = try JSONEncoder().encode(GoogleReaderCompatibleCreateSubscription(feedURL: url))
		} catch {
			completion(.failure(error))
			return
		}
		
		transport.send(request: request, method: HTTPMethod.post, payload: payload) { result in
			
			switch result {
			case .success(let (response, data)):
				
				switch response.forcedStatusCode {
				case 201:
					guard let subData = data else {
						completion(.failure(TransportError.noData))
						break
					}
					do {
						let subscription = try JSONDecoder().decode(GoogleReaderCompatibleSubscription.self, from: subData)
						completion(.success(.created(subscription)))
					} catch {
						completion(.failure(error))
					}
				case 300:
					guard let subData = data else {
						completion(.failure(TransportError.noData))
						break
					}
					do {
						let subscriptions = try JSONDecoder().decode([GoogleReaderCompatibleSubscriptionChoice].self, from: subData)
						completion(.success(.multipleChoice(subscriptions)))
					} catch {
						completion(.failure(error))
					}
				case 302:
					completion(.success(.alreadySubscribed))
				default:
					completion(.failure(TransportError.httpError(status: response.forcedStatusCode)))
				}
				
			case .failure(let error):
				
				switch error {
				case TransportError.httpError(let status):
					switch status {
					case 401:
						// I don't know why we get 401's here.  This looks like a GoogleReaderCompatible bug, but it only happens
						// when you are already subscribed to the feed.
						completion(.success(.alreadySubscribed))
					case 404:
						completion(.success(.notFound))
					default:
						completion(.failure(error))
					}
				default:
					completion(.failure(error))
				}
				
			}
			
		}
		
	}
	
	func renameSubscription(subscriptionID: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("subscriptions/\(subscriptionID)/update.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleUpdateSubscription(title: newName)
		transport.send(request: request, method: HTTPMethod.post, payload: payload, completion: completion)
	}
	
	func deleteSubscription(subscriptionID: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("subscriptions/\(subscriptionID).json")
		let request = URLRequest(url: callURL, credentials: credentials)
		transport.send(request: request, method: HTTPMethod.delete, completion: completion)
	}
	
	func createTagging(feedID: Int, name: String, completion: @escaping (Result<Int, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("taggings.json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let payload: Data
		do {
			payload = try JSONEncoder().encode(GoogleReaderCompatibleCreateTagging(feedID: feedID, name: name))
		} catch {
			completion(.failure(error))
			return
		}
		
		transport.send(request: request, method: HTTPMethod.post, payload:payload) { result in
			
			switch result {
			case .success(let (response, _)):
				if let taggingLocation = response.valueForHTTPHeaderField(HTTPResponseHeader.location),
					let lowerBound = taggingLocation.range(of: "v2/taggings/")?.upperBound,
					let upperBound = taggingLocation.range(of: ".json")?.lowerBound,
					let taggingID = Int(taggingLocation[lowerBound..<upperBound]) {
						completion(.success(taggingID))
				} else {
					completion(.failure(TransportError.noData))
				}
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func deleteTagging(taggingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("taggings/\(taggingID).json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)
		transport.send(request: request, method: HTTPMethod.delete, completion: completion)
	}
	
	func retrieveIcons(completion: @escaping (Result<[GoogleReaderCompatibleIcon]?, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("icons.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.icons]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: [GoogleReaderCompatibleIcon].self) { result in
			
			switch result {
			case .success(let (response, icons)):
				self.storeConditionalGet(key: ConditionalGetKeys.icons, headers: response.allHeaderFields)
				completion(.success(icons))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func retrieveEntries(articleIDs: [String], completion: @escaping (Result<([GoogleReaderCompatibleEntry]?), Error>) -> Void) {
		
		guard !articleIDs.isEmpty else {
			completion(.success(([GoogleReaderCompatibleEntry]())))
			return
		}
		
		let concatIDs = articleIDs.reduce("") { param, articleID in return param + ",\(articleID)" }
		let paramIDs = String(concatIDs.dropFirst())
		
		var callComponents = URLComponents(url: GoogleReaderCompatibleBaseURL.appendingPathComponent("entries.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "ids", value: paramIDs), URLQueryItem(name: "mode", value: "extended")]
		let request = URLRequest(url: callComponents.url!, credentials: credentials)
		
		transport.send(request: request, resultType: [GoogleReaderCompatibleEntry].self) { result in
			
			switch result {
			case .success(let (_, entries)):
				completion(.success((entries)))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func retrieveEntries(feedID: String, completion: @escaping (Result<([GoogleReaderCompatibleEntry]?, String?), Error>) -> Void) {
		
		let since = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
		let sinceString = GoogleReaderCompatibleDate.formatter.string(from: since)
		
		var callComponents = URLComponents(url: GoogleReaderCompatibleBaseURL.appendingPathComponent("feeds/\(feedID)/entries.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "since", value: sinceString), URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "mode", value: "extended")]
		let request = URLRequest(url: callComponents.url!, credentials: credentials)
		
		transport.send(request: request, resultType: [GoogleReaderCompatibleEntry].self) { result in
			
			switch result {
			case .success(let (response, entries)):
				
				let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
				completion(.success((entries, pagingInfo.nextPage)))
				
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func retrieveEntries(completion: @escaping (Result<([GoogleReaderCompatibleEntry]?, String?, Int?), Error>) -> Void) {
		
		let since: Date = {
			if let lastArticleFetch = accountMetadata?.lastArticleFetch {
				return lastArticleFetch
			} else {
				return Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
			}
		}()
		
		let sinceString = GoogleReaderCompatibleDate.formatter.string(from: since)
		var callComponents = URLComponents(url: GoogleReaderCompatibleBaseURL.appendingPathComponent("entries.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "since", value: sinceString), URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "mode", value: "extended")]
		let request = URLRequest(url: callComponents.url!, credentials: credentials)
		
		transport.send(request: request, resultType: [GoogleReaderCompatibleEntry].self) { result in
			
			switch result {
			case .success(let (response, entries)):
				
				let dateInfo = HTTPDateInfo(urlResponse: response)
				self.accountMetadata?.lastArticleFetch = dateInfo?.date

				let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
				let lastPageNumber = self.extractPageNumber(link: pagingInfo.lastPage)
				completion(.success((entries, pagingInfo.nextPage, lastPageNumber)))
				
			case .failure(let error):
				self.accountMetadata?.lastArticleFetch = nil
				completion(.failure(error))
			}
			
		}
		
	}
	
	func retrieveEntries(page: String, completion: @escaping (Result<([GoogleReaderCompatibleEntry]?, String?), Error>) -> Void) {
		
		guard let url = URL(string: page), var callComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			completion(.success((nil, nil)))
			return
		}
		
		callComponents.queryItems?.append(URLQueryItem(name: "mode", value: "extended"))
		let request = URLRequest(url: callComponents.url!, credentials: credentials)

		transport.send(request: request, resultType: [GoogleReaderCompatibleEntry].self) { result in
			
			switch result {
			case .success(let (response, entries)):
				
				let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
				completion(.success((entries, pagingInfo.nextPage)))

			case .failure(let error):
				self.accountMetadata?.lastArticleFetch = nil
				completion(.failure(error))
			}
			
		}
		
	}

	func retrieveUnreadEntries(completion: @escaping (Result<[Int]?, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("unread_entries.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.unreadEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: [Int].self) { result in
			
			switch result {
			case .success(let (response, unreadEntries)):
				self.storeConditionalGet(key: ConditionalGetKeys.unreadEntries, headers: response.allHeaderFields)
				completion(.success(unreadEntries))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func createUnreadEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleUnreadEntry(unreadEntries: entries)
		transport.send(request: request, method: HTTPMethod.post, payload: payload, completion: completion)
	}
	
	func deleteUnreadEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleUnreadEntry(unreadEntries: entries)
		transport.send(request: request, method: HTTPMethod.delete, payload: payload, completion: completion)
	}
	
	func retrieveStarredEntries(completion: @escaping (Result<[Int]?, Error>) -> Void) {
		
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("starred_entries.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.starredEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: [Int].self) { result in
			
			switch result {
			case .success(let (response, starredEntries)):
				self.storeConditionalGet(key: ConditionalGetKeys.starredEntries, headers: response.allHeaderFields)
				completion(.success(starredEntries))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func createStarredEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleStarredEntry(starredEntries: entries)
		transport.send(request: request, method: HTTPMethod.post, payload: payload, completion: completion)
	}
	
	func deleteStarredEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = GoogleReaderCompatibleBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = GoogleReaderCompatibleStarredEntry(starredEntries: entries)
		transport.send(request: request, method: HTTPMethod.delete, payload: payload, completion: completion)
	}
	
}

// MARK: Private

extension GoogleReaderCompatibleAPICaller {
	
	func storeConditionalGet(key: String, headers: [AnyHashable : Any]) {
		if var conditionalGet = accountMetadata?.conditionalGetInfo {
			conditionalGet[key] = HTTPConditionalGetInfo(headers: headers)
			accountMetadata?.conditionalGetInfo = conditionalGet
		}
	}
	
	func extractPageNumber(link: String?) -> Int? {
		
		guard let link = link else {
			return nil
		}
		
		if let lowerBound = link.range(of: "page=")?.upperBound {
			if let upperBound = link.range(of: "&")?.lowerBound {
				return Int(link[lowerBound..<upperBound])
			}
			if let upperBound = link.range(of: ">")?.lowerBound {
				return Int(link[lowerBound..<upperBound])
			}
		}
		
		return nil
		
	}
	
}
