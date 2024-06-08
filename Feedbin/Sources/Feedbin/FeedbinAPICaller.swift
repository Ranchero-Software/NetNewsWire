//
//  FeedbinAPICaller.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

// Feedbin currently has a maximum of 250 requests per second.  If you begin to receive
// HTTP Response Codes of 403, you have exceeded this limit.  Wait 5 minutes and your
// IP address will become unblocked and you can use the service again.

import Foundation
import FoundationExtras
import Web
import Secrets

public enum CreateSubscriptionResult: Sendable {
	case created(FeedbinSubscription)
	case multipleChoice([FeedbinSubscriptionChoice])
	case alreadySubscribed
	case notFound
}

public protocol FeedbinAPICallerDelegate: AnyObject {

	@MainActor var conditionalGetInfo: [String: HTTPConditionalGetInfo] { get set }
	@MainActor var lastArticleFetchStartTime: Date? { get }
}

@MainActor public final class FeedbinAPICaller {

	public struct ConditionalGetKeys {
		public static let subscriptions = "subscriptions"
		public static let tags = "tags"
		public static let taggings = "taggings"
		public static let unreadEntries = "unreadEntries"
		public static let starredEntries = "starredEntries"
	}
	
	private let feedbinBaseURL = URL(string: "https://api.feedbin.com/v2/")!
	private var transport: Transport!
	private var suspended = false
	private var lastBackdateStartTime: Date?
	
	public var credentials: Credentials?
	public weak var delegate: FeedbinAPICallerDelegate?

	public init(transport: Transport) {
		self.transport = transport
	}
	
	/// Cancels all pending requests rejects any that come in later
	public func suspend() {
		transport.cancelAll()
		suspended = true
	}
	
	public func resume() {
		suspended = false
	}
	
	public func validateCredentials() async throws -> Credentials? {

		let callURL = feedbinBaseURL.appendingPathComponent("authentication.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)

		do {
			try await transport.send(request: request)
			return credentials
		} catch {
			if case TransportError.httpError(let status) = error, status == 401 {
				return nil
			}
			throw error
		}
	}

	public func importOPML(opmlData: Data) async throws -> FeedbinImportResult {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("imports.json")
		var request = URLRequest(url: callURL, feedbinCredentials: credentials)
		request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let (_, data) = try await transport.send(request: request, method: HTTPMethod.post, payload: opmlData)
		guard let data else {
			throw TransportError.noData
		}

		let parsingTask = Task.detached { () throws -> FeedbinImportResult in
			try JSONDecoder().decode(FeedbinImportResult.self, from: data)
		}

		let importResult = try await parsingTask.value
		return importResult
	}

	public func retrieveOPMLImportResult(importID: Int) async throws -> FeedbinImportResult? {

		let callURL = feedbinBaseURL.appendingPathComponent("imports/\(importID).json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)

		let (_, importResult) = try await transport.send(request: request, resultType: FeedbinImportResult.self)
		return importResult
	}

	public func retrieveTags() async throws -> [FeedbinTag]? {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let conditionalGet = delegate?.conditionalGetInfo[ConditionalGetKeys.tags]
		let request = URLRequest(url: callURL, feedbinCredentials: credentials, conditionalGet: conditionalGet)

		let (response, tags) = try await transport.send(request: request, resultType: [FeedbinTag].self)

		storeConditionalGet(key: ConditionalGetKeys.tags, headers: response.allHeaderFields)

		return tags
	}

	public func renameTag(oldName: String, newName: String) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)
		let payload = FeedbinRenameTag(oldName: oldName, newName: newName)
		
		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}
	
	public func retrieveSubscriptions() async throws -> [FeedbinSubscription]? {

		if suspended { throw TransportError.suspended }

		var callComponents = URLComponents(url: feedbinBaseURL.appendingPathComponent("subscriptions.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "mode", value: "extended")]

		let conditionalGet = delegate?.conditionalGetInfo[ConditionalGetKeys.subscriptions]
		let request = URLRequest(url: callComponents.url!, feedbinCredentials: credentials, conditionalGet: conditionalGet)

		let (response, subscriptions) = try await transport.send(request: request, resultType: [FeedbinSubscription].self)

		storeConditionalGet(key: ConditionalGetKeys.subscriptions, headers: response.allHeaderFields)

		return subscriptions
	}
	
	public func createSubscription(url: String) async throws -> CreateSubscriptionResult {

		if suspended { throw TransportError.suspended }

		var callComponents = URLComponents(url: feedbinBaseURL.appendingPathComponent("subscriptions.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "mode", value: "extended")]

		var request = URLRequest(url: callComponents.url!, feedbinCredentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let payload: Data
		do {
			payload = try JSONEncoder().encode(FeedbinCreateSubscription(feedURL: url))
		} catch {
			throw error
		}

		do {
			let (response, data) = try await transport.send(request: request, method: HTTPMethod.post, payload: payload)

			switch response.forcedStatusCode {

			case 201:
				guard let subData = data else {
					throw TransportError.noData
				}
				let subscription = try JSONDecoder().decode(FeedbinSubscription.self, from: subData)
				return .created(subscription)

			case 300:
				guard let subData = data else {
					throw TransportError.noData
				}
				let subscriptions = try JSONDecoder().decode([FeedbinSubscriptionChoice].self, from: subData)
				return .multipleChoice(subscriptions)

			case 302:
				return .alreadySubscribed

			default:
				throw TransportError.httpError(status: response.forcedStatusCode)
			}
		} catch {

			switch error {
			case TransportError.httpError(let status):
				switch status {
				case 401:
					// I don't know why we get 401's here.  This looks like a Feedbin bug, but it only happens
					// when you are already subscribed to the feed.
					return .alreadySubscribed
				case 404:
					return .notFound
				default:
					throw error
				}
			default:
				throw error
			}
		}
	}

	public func renameSubscription(subscriptionID: String, newName: String) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("subscriptions/\(subscriptionID)/update.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)
		let payload = FeedbinUpdateSubscription(title: newName)
		
		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}
	
	public func deleteSubscription(subscriptionID: String) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("subscriptions/\(subscriptionID).json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)

		try await transport.send(request: request, method: HTTPMethod.delete)
	}
	
	public func retrieveTaggings() async throws -> [FeedbinTagging]? {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("taggings.json")
		let conditionalGet = delegate?.conditionalGetInfo[ConditionalGetKeys.taggings]
		let request = URLRequest(url: callURL, feedbinCredentials: credentials, conditionalGet: conditionalGet)

		let (response, taggings) = try await transport.send(request: request, resultType: [FeedbinTagging].self)

		storeConditionalGet(key: ConditionalGetKeys.taggings, headers: response.allHeaderFields)

		return taggings
	}

	public func createTagging(feedID: Int, name: String) async throws -> Int {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("taggings.json")
		var request = URLRequest(url: callURL, feedbinCredentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let payload = try JSONEncoder().encode(FeedbinCreateTagging(feedID: feedID, name: name))

		let (response, _) = try await transport.send(request: request, method: HTTPMethod.post, payload:payload)

		if let taggingLocation = response.valueForHTTPHeaderField(HTTPResponseHeader.location),
		   let lowerBound = taggingLocation.range(of: "v2/taggings/")?.upperBound,
		   let upperBound = taggingLocation.range(of: ".json")?.lowerBound,
		   let taggingID = Int(taggingLocation[lowerBound..<upperBound]) {
			return taggingID
		} else {
			throw TransportError.noData
		}
	}

	public func deleteTagging(taggingID: String) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("taggings/\(taggingID).json")
		var request = URLRequest(url: callURL, feedbinCredentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		try await transport.send(request: request, method: HTTPMethod.delete)
	}

	public func retrieveEntries(articleIDs: [String]) async throws -> [FeedbinEntry]? {

		if suspended { throw TransportError.suspended }

		guard !articleIDs.isEmpty else {
			return nil
		}
		
		let concatIDs = articleIDs.reduce("") { param, articleID in return param + ",\(articleID)" }
		let paramIDs = String(concatIDs.dropFirst())
		
		let url = feedbinBaseURL
			.appendingPathComponent("entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "ids", value: paramIDs),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, feedbinCredentials: credentials)

		let (_, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)
		return entries
	}

	public func retrieveEntries(feedID: String) async throws -> ([FeedbinEntry]?, String?) {

		if suspended { throw TransportError.suspended }

		let since = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
		let sinceString = FeedbinDate.formatter.string(from: since)
		
		let url = feedbinBaseURL
			.appendingPathComponent("feeds/\(feedID)/entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "since", value: sinceString),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, feedbinCredentials: credentials)

		let (response, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)
	
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		return (entries, pagingInfo.nextPage)
	}

	public func retrieveEntries() async throws -> ([FeedbinEntry]?, String?, Date?, Int?) {

		if suspended { throw TransportError.suspended }

		// If this is an initial sync, go and grab the previous 3 months of entries.  If not, use the last
		// article fetch to only get the articles **published** since the last article fetch.
		//
		// We do a backdate fetch every launch or every 24 hours.  This will help with
		// getting **updated** articles that normally wouldn't be found with a regular fetch.
		// https://github.com/Ranchero-Software/NetNewsWire/issues/2549#issuecomment-722341356
		let since: Date = {
			if let lastArticleFetch = delegate?.lastArticleFetchStartTime {
				if let lastBackdateStartTime = lastBackdateStartTime {
					if lastBackdateStartTime.byAdding(days: 1) < lastArticleFetch {
						self.lastBackdateStartTime = lastArticleFetch
						return lastArticleFetch.bySubtracting(days: 1)
					} else {
						return lastArticleFetch
					}
				} else {
					self.lastBackdateStartTime = lastArticleFetch
					return lastArticleFetch.bySubtracting(days: 1)
				}
			} else {
				return Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
			}
		}()
		
		let sinceString = FeedbinDate.formatter.string(from: since)
		let url = feedbinBaseURL
			.appendingPathComponent("entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "since", value: sinceString),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, feedbinCredentials: credentials)

		let (response, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)

		let dateInfo = HTTPDateInfo(urlResponse: response)

		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		let lastPageNumber = self.extractPageNumber(link: pagingInfo.lastPage)
		return (entries, pagingInfo.nextPage, dateInfo?.date, lastPageNumber)
	}
	
	public func retrieveEntries(page: String) async throws -> ([FeedbinEntry]?, String?) {

		if suspended { throw TransportError.suspended }

		guard let url = URL(string: page) else {
			return (nil, nil)
		}

		let request = URLRequest(url: url, feedbinCredentials: credentials)

		let (response, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)

		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		return (entries, pagingInfo.nextPage)
	}

	public func retrieveUnreadEntries() async throws -> [Int]? {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("unread_entries.json")
		let conditionalGet = delegate?.conditionalGetInfo[ConditionalGetKeys.unreadEntries]
		let request = URLRequest(url: callURL, feedbinCredentials: credentials, conditionalGet: conditionalGet)

		let (response, unreadEntries) = try await transport.send(request: request, resultType: [Int].self)

		storeConditionalGet(key: ConditionalGetKeys.unreadEntries, headers: response.allHeaderFields)
		return unreadEntries
	}
	
	public func createUnreadEntries(entries: [Int]) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)
		let payload = FeedbinUnreadEntry(unreadEntries: entries)

		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}

	public func deleteUnreadEntries(entries: [Int]) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)
		let payload = FeedbinUnreadEntry(unreadEntries: entries)

		try await transport.send(request: request, method: HTTPMethod.delete, payload: payload)
	}

	public func retrieveStarredEntries() async throws -> [Int]? {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("starred_entries.json")
		let conditionalGet = delegate?.conditionalGetInfo[ConditionalGetKeys.starredEntries]
		let request = URLRequest(url: callURL, feedbinCredentials: credentials, conditionalGet: conditionalGet)

		let (response, starredEntries) = try await transport.send(request: request, resultType: [Int].self)

		storeConditionalGet(key: ConditionalGetKeys.starredEntries, headers: response.allHeaderFields)
		return starredEntries
	}

	public func createStarredEntries(entries: [Int]) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)
		let payload = FeedbinStarredEntry(starredEntries: entries)
		
		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}
	
	public func deleteStarredEntries(entries: [Int]) async throws {

		if suspended { throw TransportError.suspended }

		let callURL = feedbinBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, feedbinCredentials: credentials)
		let payload = FeedbinStarredEntry(starredEntries: entries)
		
		try await transport.send(request: request, method: HTTPMethod.delete, payload: payload)
	}
}

// MARK: Private

private extension FeedbinAPICaller {
	
	func storeConditionalGet(key: String, headers: [AnyHashable : Any]) {
		if var conditionalGet = delegate?.conditionalGetInfo {
			conditionalGet[key] = HTTPConditionalGetInfo(headers: headers)
			delegate?.conditionalGetInfo = conditionalGet
		}
	}
	
	func extractPageNumber(link: String?) -> Int? {
		
		guard let link = link else {
			return nil
		}
		
		if let lowerBound = link.range(of: "page=")?.upperBound {
			let partialLink = link[lowerBound..<link.endIndex]
			if let upperBound = partialLink.firstIndex(of: "&") {
				return Int(partialLink[partialLink.startIndex..<upperBound])
			}
			if let upperBound = partialLink.firstIndex(of: ">") {
				return Int(partialLink[partialLink.startIndex..<upperBound])
			}
		}
		
		return nil
		
	}
	
}

private extension URLRequest {

	init(url: URL, feedbinCredentials: Credentials?, conditionalGet: HTTPConditionalGetInfo? = nil) {

		self.init(url: url)

		guard let credentials = feedbinCredentials else {
			return
		}

		precondition(credentials.type == .basic)

		let data = "\(credentials.username):\(credentials.secret)".data(using: .utf8)
		let base64 = data?.base64EncodedString()
		let auth = "Basic \(base64 ?? "")"
		setValue(auth, forHTTPHeaderField: HTTPRequestHeader.authorization)

		conditionalGet?.addRequestHeadersToURLRequest(&self)
	}
}
