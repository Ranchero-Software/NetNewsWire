//
//  ReaderAPICaller.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Secrets

enum CreateReaderAPISubscriptionResult {
	case created(ReaderAPISubscription)
	case notFound
}

final class ReaderAPICaller {

	enum ItemIDType {
		case unread
		case starred
		case allForAccount
		case allForFeed
	}

	private enum ReaderState: String {
		case read = "user/-/state/com.google/read"
		case starred = "user/-/state/com.google/starred"
	}

	private enum ReaderStreams: String {
		case readingList = "user/-/state/com.google/reading-list"
	}

	private enum ReaderAPIEndpoints: String {
		case login = "/accounts/ClientLogin"
		case token = "/reader/api/0/token"
		case disableTag = "/reader/api/0/disable-tag"
		case renameTag = "/reader/api/0/rename-tag"
		case tagList = "/reader/api/0/tag/list"
		case subscriptionList = "/reader/api/0/subscription/list"
		case subscriptionEdit = "/reader/api/0/subscription/edit"
		case subscriptionAdd = "/reader/api/0/subscription/quickadd"
		case contents = "/reader/api/0/stream/items/contents"
		case itemIds = "/reader/api/0/stream/items/ids"
		case editTag = "/reader/api/0/edit-tag"
	}

	private let transport: Transport
	private let uriComponentAllowed: CharacterSet

	private var accessToken: String?

	weak var accountMetadata: AccountMetadata?

	var variant: ReaderAPIVariant = .generic
	var credentials: Credentials?

	@MainActor var server: String? {
		get {
			return apiBaseURL?.host
		}
	}

	@MainActor private var apiBaseURL: URL? {
		get {
			switch variant {
			case .generic, .freshRSS:
				guard let accountMetadata = accountMetadata else {
					return nil
				}
				return accountMetadata.endpointURL
			default:
				return URL(string: variant.host)
			}
		}
	}

	init(transport: Transport) {
		self.transport = transport

		var urlHostAllowed = CharacterSet.urlHostAllowed
		urlHostAllowed.remove("+")
		urlHostAllowed.remove("&")
		uriComponentAllowed = urlHostAllowed
	}

	func cancelAll() {
		transport.cancelAll()
	}

	public func validateCredentials(endpoint: URL) async throws -> Credentials? {

		guard let credentials else {
			throw CredentialsError.incompleteCredentials
		}

		var request = URLRequest(url: endpoint.appendingPathComponent(ReaderAPIEndpoints.login.rawValue), readerAPICredentials: credentials)
		addVariantHeaders(&request)

		do {
			let (_, data) = try await transport.send(request: request)

			guard let data else {
				throw TransportError.noData
			}

			// Convert the return data to UTF8 and then parse out the Auth token
			guard let rawData = String(data: data, encoding: .utf8) else {
				throw TransportError.noData
			}

			var authData: [String: String] = [:]
			for line in rawData.split(separator: "\n") {
				let items = line.split(separator: "=").map { String($0) }
				if items.count == 2 {
					authData[items[0]] = items[1]
				}
			}

			guard let authString = authData["Auth"] else {
				throw CredentialsError.incompleteCredentials
			}

			// Save Auth Token for later use
			self.credentials = Credentials(type: .readerAPIKey, username: credentials.username, secret: authString)

			return self.credentials

		} catch {
			if let transportError = error as? TransportError, case .httpError(let code) = transportError, code == 404 {
				throw AccountError.urlNotFound
			} else {
				throw error
			}
		}
	}

	func requestAuthorizationToken(endpoint: URL) async throws -> String {
		// If we have a token already, use it
		if let accessToken {
			return accessToken
		}

		// Otherwise request one.
		guard let credentials else {
			throw CredentialsError.incompleteCredentials
		}

		var request = URLRequest(url: endpoint.appendingPathComponent(ReaderAPIEndpoints.token.rawValue), readerAPICredentials: credentials)
		addVariantHeaders(&request)

		let (_, data) = try await transport.send(request: request)

		// Convert the return data to UTF8 and then parse out the Auth token
		guard let data, let accessToken = String(data: data, encoding: .utf8) else {
			throw TransportError.noData
		}

		self.accessToken = accessToken
		return accessToken
	}

	@MainActor public func retrieveTags() async throws -> [ReaderAPITag]? {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		var url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.tagList.rawValue)
			.appendingQueryItem(URLQueryItem(name: "output", value: "json"))

		if variant == .inoreader {
			url = url?.appendingQueryItem(URLQueryItem(name: "types", value: "1"))
		}

		guard let callURL = url else {
			throw TransportError.noURL
		}

		var request = URLRequest(url: callURL, readerAPICredentials: credentials)
		addVariantHeaders(&request)

		let (_, wrapper) = try await transport.send(request: request, resultType: ReaderAPITagContainer.self)
		return wrapper?.tags
	}

	@MainActor public func renameTag(oldName: String, newName: String) async throws {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await requestAuthorizationToken(endpoint: baseURL)

		var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.renameTag.rawValue), readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		guard let encodedOldName = self.encodeForURLPath(oldName), let encodedNewName = self.encodeForURLPath(newName) else {
			throw AccountError.invalidParameter
		}

		let oldTagName = "user/-/label/\(encodedOldName)"
		let newTagName = "user/-/label/\(encodedNewName)"
		let postData = "T=\(token)&s=\(oldTagName)&dest=\(newTagName)".data(using: String.Encoding.utf8)

		_ = try await transport.send(request: request, method: HTTPMethod.post, payload: postData!)
	}

	@MainActor public func deleteTag(folderExternalID: String) async throws {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await self.requestAuthorizationToken(endpoint: baseURL)

		var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.disableTag.rawValue), readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		let postData = "T=\(token)&s=\(folderExternalID)".data(using: String.Encoding.utf8)

		_ = try await self.transport.send(request: request, method: HTTPMethod.post, payload: postData!)
	}

	@MainActor public func retrieveSubscriptions() async throws -> [ReaderAPISubscription]? {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.subscriptionList.rawValue)
			.appendingQueryItem(URLQueryItem(name: "output", value: "json"))

		guard let callURL = url else {
			throw TransportError.noURL
		}

		var request = URLRequest(url: callURL, readerAPICredentials: credentials)
		addVariantHeaders(&request)

		let (_, container) = try await transport.send(request: request, resultType: ReaderAPISubscriptionContainer.self)
		return container?.subscriptions
	}

	@MainActor public func createSubscription(url: String, name: String?) async throws -> CreateReaderAPISubscriptionResult {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await self.requestAuthorizationToken(endpoint: baseURL)

		let callURL = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.subscriptionAdd.rawValue)

		var request = URLRequest(url: callURL, readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		guard let encodedFeedURL = self.encodeForURLPath(url) else {
			throw AccountError.invalidParameter
		}

		let postData = "T=\(token)&quickadd=\(encodedFeedURL)".data(using: String.Encoding.utf8)

		let (_, subResult) = try await self.transport.send(request: request, method: HTTPMethod.post, data: postData!, resultType: ReaderAPIQuickAddResult.self)

		guard let subResult else {
			return .notFound
		}
		if subResult.numResults == 0 {
			return .notFound
		}

		// There is no call to get a single subscription entry, so we get them all,
		// look up the one we just subscribed to and return that
		guard let subscriptions = try await retrieveSubscriptions() else {
			throw AccountError.createErrorNotFound
		}
		guard let subscription = subscriptions.first(where: { $0.feedID == subResult.streamId }) else {
			throw AccountError.createErrorNotFound
		}

		return .created(subscription)
	}


	public func renameSubscription(subscriptionID: String, newName: String) async throws {

		try await changeSubscription(subscriptionID: subscriptionID, title: newName)
	}

	@MainActor public func deleteSubscription(subscriptionID: String) async throws {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await self.requestAuthorizationToken(endpoint: baseURL)

		var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.subscriptionEdit.rawValue), readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		let postData = "T=\(token)&s=\(subscriptionID)&ac=unsubscribe".data(using: String.Encoding.utf8)

		_ = try await self.transport.send(request: request, method: HTTPMethod.post, payload: postData!)
	}

	public func createTagging(subscriptionID: String, tagName: String) async throws {

		try await changeSubscription(subscriptionID: subscriptionID, addTagName: tagName)
	}

	public func deleteTagging(subscriptionID: String, tagName: String) async throws {

		try await changeSubscription(subscriptionID: subscriptionID, removeTagName: tagName)
	}

	public func moveSubscription(subscriptionID: String, sourceTag: String, destinationTag: String) async throws {

		try await changeSubscription(subscriptionID: subscriptionID, removeTagName: sourceTag, addTagName: destinationTag)
	}

	@MainActor private func changeSubscription(subscriptionID: String, removeTagName: String? = nil, addTagName: String? = nil, title: String? = nil) async throws {

		guard removeTagName != nil || addTagName != nil || title != nil else {
			throw AccountError.invalidParameter
		}
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await requestAuthorizationToken(endpoint: baseURL)

		var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.subscriptionEdit.rawValue), readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		var postString = "T=\(token)&s=\(subscriptionID)&ac=edit"
		if let fromLabel = self.encodeForURLPath(removeTagName) {
			postString += "&r=user/-/label/\(fromLabel)"
		}
		if let toLabel = self.encodeForURLPath(addTagName) {
			postString += "&a=user/-/label/\(toLabel)"
		}
		if let encodedTitle = self.encodeForURLPath(title) {
			postString += "&t=\(encodedTitle)"
		}
		let postData = postString.data(using: String.Encoding.utf8)

		_ = try await transport.send(request: request, method: HTTPMethod.post, payload: postData!)
	}

	@MainActor public func retrieveEntries(articleIDs: [String]) async throws -> [ReaderAPIEntry]? {

		guard !articleIDs.isEmpty else {
			return [ReaderAPIEntry]()
		}
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await requestAuthorizationToken(endpoint: baseURL)

		var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.contents.rawValue), readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		// Get ids from above into hex representation of value
		let idsToFetch = articleIDs.map({ articleID -> String in
			if self.variant == .theOldReader {
				return "i=tag:google.com,2005:reader/item/\(articleID)"
			} else {
				let idValue = Int(articleID)!
				let idHexString = String(idValue, radix: 16, uppercase: false)
				return "i=tag:google.com,2005:reader/item/\(idHexString)"
			}
		}).joined(separator:"&")

		let postData = "T=\(token)&output=json&\(idsToFetch)".data(using: String.Encoding.utf8)

		let (_, entryWrapper) = try await transport.send(request: request, method: HTTPMethod.post, data: postData!, resultType: ReaderAPIEntryWrapper.self)

		guard let entryWrapper else {
			throw AccountError.invalidResponse
		}

		return entryWrapper.entries
	}

	@MainActor public func retrieveItemIDs(type: ItemIDType, feedID: String? = nil) async throws -> [String] {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		var queryItems = [
			URLQueryItem(name: "n", value: "1000"),
			URLQueryItem(name: "output", value: "json")
		]

		switch type {
		case .allForAccount:
			let since: Date = {
				if let lastArticleFetch = self.accountMetadata?.lastArticleFetchStartTime {
					return lastArticleFetch
				} else {
					return Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
				}
			}()

			let sinceTimeInterval = since.timeIntervalSince1970
			queryItems.append(URLQueryItem(name: "ot", value: String(Int(sinceTimeInterval))))
			queryItems.append(URLQueryItem(name: "s", value: ReaderStreams.readingList.rawValue))
		case .allForFeed:
			guard let feedID else {
				throw AccountError.invalidParameter
			}
			let sinceTimeInterval = (Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()).timeIntervalSince1970
			queryItems.append(URLQueryItem(name: "ot", value: String(Int(sinceTimeInterval))))
			queryItems.append(URLQueryItem(name: "s", value: feedID))
		case .unread:
			queryItems.append(URLQueryItem(name: "s", value: ReaderStreams.readingList.rawValue))
			queryItems.append(URLQueryItem(name: "xt", value: ReaderState.read.rawValue))
		case .starred:
			queryItems.append(URLQueryItem(name: "s", value: ReaderState.starred.rawValue))
		}

		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.itemIds.rawValue)
			.appendingQueryItems(queryItems)

		guard let callURL = url else {
			throw TransportError.noURL
		}

		var request: URLRequest = URLRequest(url: callURL, readerAPICredentials: credentials)
		addVariantHeaders(&request)

		let (response, entries) = try await transport.send(request: request, resultType: ReaderAPIReferenceWrapper.self)

		guard let entriesItemRefs = entries?.itemRefs, entriesItemRefs.count > 0 else {
			return [String]()
		}

		let dateInfo = HTTPDateInfo(urlResponse: response)
		let itemIDs = entriesItemRefs.compactMap { $0.itemId }

		return try await retrieveItemIDs(type: type, url: callURL, dateInfo: dateInfo, itemIDs: itemIDs, continuation: entries?.continuation)
	}

	@MainActor func retrieveItemIDs(type: ItemIDType, url: URL, dateInfo: HTTPDateInfo?, itemIDs: [String], continuation: String?) async throws -> [String] {

		guard let continuation else {
			if type == .allForAccount {
				self.accountMetadata?.lastArticleFetchStartTime = dateInfo?.date
				self.accountMetadata?.lastArticleFetchEndTime = Date()
			}
			return itemIDs
		}

		guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			throw AccountError.invalidParameter
		}

		var queryItems = urlComponents.queryItems!.filter({ $0.name != "c" })
		queryItems.append(URLQueryItem(name: "c", value: continuation))
		urlComponents.queryItems = queryItems

		guard let callURL = urlComponents.url else {
			throw TransportError.noURL
		}

		var request: URLRequest = URLRequest(url: callURL, readerAPICredentials: credentials)
		addVariantHeaders(&request)

		let (_, entries) = try await self.transport.send(request: request, resultType: ReaderAPIReferenceWrapper.self)

		guard let entriesItemRefs = entries?.itemRefs, entriesItemRefs.count > 0 else {
			return try await retrieveItemIDs(type: type, url: callURL, dateInfo: dateInfo, itemIDs: itemIDs, continuation: entries?.continuation)
		}

		var totalItemIDs = itemIDs
		totalItemIDs.append(contentsOf: entriesItemRefs.compactMap { $0.itemId })

		return try await retrieveItemIDs(type: type, url: callURL, dateInfo: dateInfo, itemIDs: totalItemIDs, continuation: entries?.continuation)
	}

	public func createUnreadEntries(entries: [String]) async throws {

		try await updateStateToEntries(entries: entries, state: .read, add: false)
	}

	public func deleteUnreadEntries(entries: [String]) async throws {

		try await updateStateToEntries(entries: entries, state: .read, add: true)
	}

	public func createStarredEntries(entries: [String]) async throws {

		try await updateStateToEntries(entries: entries, state: .starred, add: true)
	}

	public func deleteStarredEntries(entries: [String]) async throws {

		try await updateStateToEntries(entries: entries, state: .starred, add: false)
	}
}

// MARK: Private

private extension ReaderAPICaller {

	func encodeForURLPath(_ pathComponent: String?) -> String? {
		guard let pathComponent = pathComponent else { return nil }
		return pathComponent.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed)
	}

	func addVariantHeaders(_ request: inout URLRequest) {
		if variant == .inoreader {
			request.addValue(SecretKey.inoreaderAppID, forHTTPHeaderField: "AppId")
			request.addValue(SecretKey.inoreaderAppKey, forHTTPHeaderField: "AppKey")
		}
	}

	@MainActor private func updateStateToEntries(entries: [String], state: ReaderState, add: Bool) async throws {

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.incompleteCredentials
		}

		let token = try await requestAuthorizationToken(endpoint: baseURL)

		// Do POST asking for data about all the new articles
		var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.editTag.rawValue), readerAPICredentials: self.credentials)
		self.addVariantHeaders(&request)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"

		// Get ids from above into hex representation of value
		let idsToFetch = entries.compactMap({ idValue -> String? in
			if self.variant == .theOldReader {
				return "i=tag:google.com,2005:reader/item/\(idValue)"
			} else {
				guard let intValue = Int(idValue) else { return nil }
				let idHexString = String(format: "%.16llx", intValue)
				return "i=tag:google.com,2005:reader/item/\(idHexString)"
			}
		}).joined(separator:"&")

		let actionIndicator = add ? "a" : "r"

		let postData = "T=\(token)&\(idsToFetch)&\(actionIndicator)=\(state.rawValue)".data(using: String.Encoding.utf8)

		_ = try await transport.send(request: request, method: HTTPMethod.post, payload: postData!)
	}
}
