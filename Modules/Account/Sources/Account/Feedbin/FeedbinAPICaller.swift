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
import RSWeb
import Secrets

enum CreateSubscriptionResult {
	case created(FeedbinSubscription)
	case multipleChoice([FeedbinSubscriptionChoice])
	case alreadySubscribed
	case notFound
}

@MainActor final class FeedbinAPICaller {
	struct ConditionalGetKeys {
		static let subscriptions = "subscriptions"
		static let tags = "tags"
		static let taggings = "taggings"
		static let unreadEntries = "unreadEntries"
		static let starredEntries = "starredEntries"
	}

	private let feedbinBaseURL = URL(string: "https://api.feedbin.com/v2/")!
	private let transport: Transport
	private var suspended = false
	private var lastBackdateStartTime: Date?

	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?

	init(transport: Transport) {
		self.transport = transport
	}

	/// Cancels all pending requests rejects any that come in later
	func suspend() {
		transport.cancelAll()
		suspended = true
	}

	func resume() {
		suspended = false
	}

	func validateCredentials() async throws -> Credentials? {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("authentication.json")
		let request = URLRequest(url: callURL, credentials: credentials)

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

	func importOPML(opmlData: Data) async throws -> FeedbinImportResult {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("imports.json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let (_, data) = try await transport.send(request: request, method: HTTPMethod.post, payload: opmlData)

		guard let data else {
			throw TransportError.noData
		}

		let importResult = try JSONDecoder().decode(FeedbinImportResult.self, from: data)
		return importResult
	}

	func retrieveOPMLImportResult(importID: Int) async throws -> FeedbinImportResult? {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("imports/\(importID).json")
		let request = URLRequest(url: callURL, credentials: credentials)

		let (_, importResult) = try await transport.send(request: request, resultType: FeedbinImportResult.self)

		return importResult
	}

	func retrieveTags() async throws -> [FeedbinTag]? {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.tags]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		let (response, tags) = try await transport.send(request: request, resultType: [FeedbinTag].self)
		storeConditionalGet(key: ConditionalGetKeys.tags, headers: response.allHeaderFields)
		return tags
	}

	func renameTag(oldName: String, newName: String) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinRenameTag(oldName: oldName, newName: newName)

		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}

	func retrieveSubscriptions() async throws -> [FeedbinSubscription]? {
		if suspended {
			throw TransportError.suspended
		}

		var callComponents = URLComponents(url: feedbinBaseURL.appendingPathComponent("subscriptions.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "mode", value: "extended")]

		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.subscriptions]
		let request = URLRequest(url: callComponents.url!, credentials: credentials, conditionalGet: conditionalGet)

		let (response, subscriptions) = try await transport.send(request: request, resultType: [FeedbinSubscription].self)
		storeConditionalGet(key: ConditionalGetKeys.subscriptions, headers: response.allHeaderFields)
		return subscriptions
	}

	func createSubscription(url: String) async throws -> CreateSubscriptionResult {
		if suspended {
			throw TransportError.suspended
		}

		var callComponents = URLComponents(url: feedbinBaseURL.appendingPathComponent("subscriptions.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "mode", value: "extended")]

		var request = URLRequest(url: callComponents.url!, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let payload = try JSONEncoder().encode(FeedbinCreateSubscription(feedURL: url))

		do {
			let (response, data) = try await transport.send(request: request, method: HTTPMethod.post, payload: payload)

			switch response.forcedStatusCode {
			case HTTPResponseCode.created: // 201
				guard let subData = data else {
					throw TransportError.noData
				}
				do {
					let subscription = try JSONDecoder().decode(FeedbinSubscription.self, from: subData)
					return .created(subscription)
				} catch {
					throw error
				}
			case HTTPResponseCode.redirectMultipleChoices: // 300
				guard let subData = data else {
					throw TransportError.noData
				}
				do {
					let subscriptions = try JSONDecoder().decode([FeedbinSubscriptionChoice].self, from: subData)
					return .multipleChoice(subscriptions)
				} catch {
					throw error
				}
			case HTTPResponseCode.redirectTemporary: // 302
				return .alreadySubscribed
			default:
				throw TransportError.httpError(status: response.forcedStatusCode)
			}
		} catch {
			switch error {
			case TransportError.httpError(let status):
				switch status {
				case HTTPResponseCode.unauthorized: // 401
					// I don’t know why we get 401s here. This looks like a Feedbin bug, but it only happens
					// when you are already subscribed to the feed.
					return .alreadySubscribed
				case HTTPResponseCode.notFound: // 404
					return .notFound
				default:
					throw error
				}
			default:
				throw error
			}
		}
	}

	func renameSubscription(subscriptionID: String, newName: String) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("subscriptions/\(subscriptionID)/update.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinUpdateSubscription(title: newName)

		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}

	func deleteSubscription(subscriptionID: String) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("subscriptions/\(subscriptionID).json")
		let request = URLRequest(url: callURL, credentials: credentials)

		try await transport.send(request: request, method: HTTPMethod.delete)
	}

	func retrieveTaggings() async throws -> [FeedbinTagging]? {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("taggings.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.taggings]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		let (response, taggings) = try await transport.send(request: request, resultType: [FeedbinTagging].self)
		storeConditionalGet(key: ConditionalGetKeys.taggings, headers: response.allHeaderFields)
		return taggings
	}

	func createTagging(feedID: Int, name: String) async throws -> Int {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("taggings.json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let payload = try JSONEncoder().encode(FeedbinCreateTagging(feedID: feedID, name: name))

		let (response, _) = try await transport.send(request: request, method: HTTPMethod.post, payload: payload)

		if let taggingLocation = response.valueForHTTPHeaderField(HTTPResponseHeader.location),
			let lowerBound = taggingLocation.range(of: "v2/taggings/")?.upperBound,
			let upperBound = taggingLocation.range(of: ".json")?.lowerBound,
			let taggingID = Int(taggingLocation[lowerBound..<upperBound]) {
				return taggingID
		} else {
			throw TransportError.noData
		}
	}

	func deleteTagging(taggingID: String) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("taggings/\(taggingID).json")
		var request = URLRequest(url: callURL, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		try await transport.send(request: request, method: HTTPMethod.delete)
	}

	func retrieveEntries(articleIDs: [String]) async throws -> [FeedbinEntry]? {
		if suspended {
			throw TransportError.suspended
		}
		guard !articleIDs.isEmpty else {
			return [FeedbinEntry]()
		}

		let concatIDs = articleIDs.reduce("") { param, articleID in return param + ",\(articleID)" }
		let paramIDs = String(concatIDs.dropFirst())
		let url = feedbinBaseURL
			.appendingPathComponent("entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "ids", value: paramIDs),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, credentials: credentials)

		let (_, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)
		return entries
	}

	func retrieveEntries(feedID: String) async throws -> ([FeedbinEntry]?, String?) {
		if suspended {
			throw TransportError.suspended
		}

		let since = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
		let sinceString = FeedbinDate.formatter.string(from: since)
		let url = feedbinBaseURL
			.appendingPathComponent("feeds/\(feedID)/entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "since", value: sinceString),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, credentials: credentials)

		let (response, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		return (entries, pagingInfo.nextPage)
	}

	func retrieveEntries() async throws -> ([FeedbinEntry]?, String?, Date?, Int?) {
		if suspended {
			throw TransportError.suspended
		}

		// If this is an initial sync, go and grab the previous 3 months of entries.  If not, use the last
		// article fetch to only get the articles **published** since the last article fetch.
		//
		// We do a backdate fetch every launch or every 24 hours.  This will help with
		// getting **updated** articles that normally wouldn't be found with a regular fetch.
		// https://github.com/Ranchero-Software/NetNewsWire/issues/2549#issuecomment-722341356
		let since: Date = {
			if let lastArticleFetch = accountMetadata?.lastArticleFetchStartTime {
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
		let request = URLRequest(url: url!, credentials: credentials)

		let (response, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)
		let dateInfo = HTTPDateInfo(urlResponse: response)
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		let lastPageNumber = extractPageNumber(link: pagingInfo.lastPage)
		return (entries, pagingInfo.nextPage, dateInfo?.date, lastPageNumber)
	}

	func retrieveEntries(page: String) async throws -> ([FeedbinEntry]?, String?) {
		if suspended {
			throw TransportError.suspended
		}

		guard let url = URL(string: page) else {
			return (nil, nil)
		}

		let request = URLRequest(url: url, credentials: credentials)
		let (response, entries) = try await transport.send(request: request, resultType: [FeedbinEntry].self)
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		return (entries, pagingInfo.nextPage)
	}

	func retrieveUnreadEntries() async throws -> [Int]? {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("unread_entries.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.unreadEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		let (response, unreadEntries) = try await transport.send(request: request, resultType: [Int].self)
		storeConditionalGet(key: ConditionalGetKeys.unreadEntries, headers: response.allHeaderFields)
		return unreadEntries
	}

	func createUnreadEntries(entries: [Int]) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinUnreadEntry(unreadEntries: entries)

		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}

	func deleteUnreadEntries(entries: [Int]) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinUnreadEntry(unreadEntries: entries)

		try await transport.send(request: request, method: HTTPMethod.delete, payload: payload)
	}

	func retrieveStarredEntries() async throws -> [Int]? {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("starred_entries.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.starredEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		let (response, starredEntries) = try await transport.send(request: request, resultType: [Int].self)
		storeConditionalGet(key: ConditionalGetKeys.starredEntries, headers: response.allHeaderFields)
		return starredEntries
	}

	func createStarredEntries(entries: [Int]) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinStarredEntry(starredEntries: entries)

		try await transport.send(request: request, method: HTTPMethod.post, payload: payload)
	}

	func deleteStarredEntries(entries: [Int]) async throws {
		if suspended {
			throw TransportError.suspended
		}

		let callURL = feedbinBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinStarredEntry(starredEntries: entries)

		try await transport.send(request: request, method: HTTPMethod.delete, payload: payload)
	}
}

// MARK: Private

extension FeedbinAPICaller {

	func storeConditionalGet(key: String, headers: [AnyHashable: Any]) {
		if var conditionalGet = accountMetadata?.conditionalGetInfo {
			conditionalGet[key] = HTTPConditionalGetInfo(headers: headers)
			accountMetadata?.conditionalGetInfo = conditionalGet
		}
	}

	func extractPageNumber(link: String?) -> Int? {
		guard let link else {
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
