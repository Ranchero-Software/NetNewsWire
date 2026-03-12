//
//  InkwellAPICaller.swift
//  Account
//
//  Created by Manton Reece on 3/11/26.
//

import Foundation
import RSWeb
import Secrets

enum InkwellAccountError: LocalizedError, Sendable {
	case inkwellNotEnabled

	var errorDescription: String? {
		switch self {
		case .inkwellNotEnabled:
			return NSLocalizedString("This Micro.blog account does not have Inkwell enabled.", comment: "Inkwell unavailable")
		}
	}

	var recoverySuggestion: String? {
		switch self {
		case .inkwellNotEnabled:
			return NSLocalizedString("Enable Inkwell for this Micro.blog account and try again.", comment: "Inkwell unavailable suggestion")
		}
	}
}

@MainActor protocol InkwellAPICallerDelegate: AnyObject {
	func inkwellAPICaller(_ caller: InkwellAPICaller, store credentials: Credentials) throws
}

struct InkwellOAuthAccessTokenRequest: Sendable {
	let code: String
	let clientId: String
	let redirectUri: String
	let grantType = "authorization_code"

	init(authorizationResponse: OAuthAuthorizationResponse, client: OAuthAuthorizationClient) {
		self.code = authorizationResponse.code
		self.clientId = client.id
		self.redirectUri = client.redirectUri
	}

	var formData: Data? {
		var components = URLComponents()
		components.queryItems = [
			URLQueryItem(name: "code", value: code),
			URLQueryItem(name: "client_id", value: clientId),
			URLQueryItem(name: "grant_type", value: grantType),
			URLQueryItem(name: "redirect_uri", value: redirectUri)
		]
		return components.enhancedPercentEncodedQuery?.data(using: .utf8)
	}
}

nonisolated struct InkwellOAuthAccessTokenResponse: Decodable, OAuthAccessTokenResponse, Sendable {
	let accessToken: String
	let tokenType: String
	let scope: String
	let me: String?
	let profile: InkwellOAuthAccessTokenProfile?
	let expiresIn = 0
	let refreshToken: String? = nil

	enum CodingKeys: String, CodingKey {
		case accessToken = "access_token"
		case tokenType = "token_type"
		case scope
		case me
		case profile
	}
}

nonisolated struct InkwellOAuthAccessTokenProfile: Decodable, Sendable {
	let name: String?
	let url: String?
	let photo: String?
}

struct InkwellVerifyResponse: Decodable, Sendable {
	let token: String
	let hasInkwell: Bool
	let name: String
	let username: String
	let avatar: String?

	enum CodingKeys: String, CodingKey {
		case token
		case hasInkwell = "has_inkwell"
		case name
		case username
		case avatar
	}
}

@MainActor final class InkwellAPICaller {
	struct ConditionalGetKeys {
		static let subscriptions = "subscriptions"
		static let unreadEntries = "unreadEntries"
		static let starredEntries = "starredEntries"
	}

	private let inkwellBaseURL = URL(string: "https://micro.blog/feeds/v2/")!
	private let oauthTokenURL = URL(string: "https://micro.blog/indieauth/token")!
	private let verifyURL = URL(string: "https://micro.blog/account/verify")!
	private let transport: Transport
	private var suspended = false
	private var lastBackdateStartTime: Date?

	weak var delegate: InkwellAPICallerDelegate?
	var credentials: Credentials?
	var accountSettings: AccountSettings?

	init(transport: Transport) {
		self.transport = transport
	}

	func suspend() {
		transport.cancelAll()
		suspended = true
	}

	func resume() {
		suspended = false
	}

	func validateCredentials() async throws -> Credentials? {
		guard let credentials else {
			throw CredentialsError.missingAccessToken
		}

		do {
			let response = try await verifyAccessToken(credentials.secret)
			guard response.hasInkwell else {
				throw InkwellAccountError.inkwellNotEnabled
			}
			return Credentials(type: .bearerAccessToken, username: response.username, secret: response.token)
		} catch {
			if case TransportError.httpError(let status) = error, status == 401 || status == 403 {
				return nil
			}
			throw error
		}
	}

	func requestAccessToken(_ authorizationRequest: InkwellOAuthAccessTokenRequest) async throws -> InkwellOAuthAccessTokenResponse {
		if suspended {
			throw TransportError.suspended
		}

		guard let formData = authorizationRequest.formData else {
			throw AccountError.invalidParameter
		}

		var request = URLRequest(url: oauthTokenURL)
		request.addValue(MimeType.formURLEncoded, forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept")

		let (_, response) = try await transport.send(request: request, method: HTTPMethod.post, data: formData, resultType: InkwellOAuthAccessTokenResponse.self)
		guard let response else {
			throw TransportError.noData
		}
		return response
	}

	func verifyAccessToken(_ token: String) async throws -> InkwellVerifyResponse {
		if suspended {
			throw TransportError.suspended
		}

		var components = URLComponents()
		components.queryItems = [URLQueryItem(name: "token", value: token)]

		guard let formData = components.enhancedPercentEncodedQuery?.data(using: .utf8) else {
			throw AccountError.invalidParameter
		}

		var request = URLRequest(url: verifyURL)
		request.addValue(MimeType.formURLEncoded, forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.addValue("application/json", forHTTPHeaderField: "Accept")

		let (_, response) = try await transport.send(request: request, method: HTTPMethod.post, data: formData, resultType: InkwellVerifyResponse.self)
		guard let response else {
			throw TransportError.noData
		}
		return response
	}

	func retrieveSubscriptions() async throws -> [FeedbinSubscription]? {
		var callComponents = URLComponents(url: inkwellBaseURL.appendingPathComponent("subscriptions.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "mode", value: "extended")]

		let conditionalGet = accountSettings?.conditionalGetInfo(for: ConditionalGetKeys.subscriptions)
		let request = URLRequest(url: callComponents.url!, credentials: credentials, conditionalGet: conditionalGet)

		let (response, subscriptions) = try await send(request: request, resultType: [FeedbinSubscription].self)
		storeConditionalGet(key: ConditionalGetKeys.subscriptions, headers: response.allHeaderFields)
		return subscriptions
	}

	func createSubscription(url: String) async throws -> CreateSubscriptionResult {
		var callComponents = URLComponents(url: inkwellBaseURL.appendingPathComponent("subscriptions.json"), resolvingAgainstBaseURL: false)!
		callComponents.queryItems = [URLQueryItem(name: "mode", value: "extended")]

		var request = URLRequest(url: callComponents.url!, credentials: credentials)
		request.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let payload = try JSONEncoder().encode(FeedbinCreateSubscription(feedURL: url))

		do {
			let (response, data) = try await send(request: request, method: HTTPMethod.post, payload: payload)

			switch response.forcedStatusCode {
			case HTTPResponseCode.created:
				guard let data else {
					throw TransportError.noData
				}
				return .created(try JSONDecoder().decode(FeedbinSubscription.self, from: data))
			case HTTPResponseCode.redirectMultipleChoices:
				guard let data else {
					throw TransportError.noData
				}
				return .multipleChoice(try JSONDecoder().decode([FeedbinSubscriptionChoice].self, from: data))
			case HTTPResponseCode.redirectTemporary:
				return .alreadySubscribed
			default:
				throw TransportError.httpError(status: response.forcedStatusCode)
			}
		} catch {
			switch error {
			case TransportError.httpError(let status):
				switch status {
				case HTTPResponseCode.notFound:
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
		let callURL = inkwellBaseURL.appendingPathComponent("subscriptions/\(subscriptionID).json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinUpdateSubscription(title: newName)

		try await send(request: request, method: HTTPMethod.patch, payload: payload)
	}

	func deleteSubscription(subscriptionID: String) async throws {
		let callURL = inkwellBaseURL.appendingPathComponent("subscriptions/\(subscriptionID).json")
		let request = URLRequest(url: callURL, credentials: credentials)

		try await send(request: request, method: HTTPMethod.delete)
	}

	func retrieveEntries(articleIDs: [String]) async throws -> [FeedbinEntry]? {
		guard !articleIDs.isEmpty else {
			return []
		}

		let concatIDs = articleIDs.reduce("") { partial, articleID in
			partial + ",\(articleID)"
		}
		let paramIDs = String(concatIDs.dropFirst())
		let url = inkwellBaseURL
			.appendingPathComponent("entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "ids", value: paramIDs),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, credentials: credentials)

		let (_, entries) = try await send(request: request, resultType: [FeedbinEntry].self)
		return entries
	}

	func retrieveEntries(feedID: String) async throws -> ([FeedbinEntry]?, String?) {
		let since = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
		let sinceString = FeedbinDate.formatter.string(from: since)
		let url = inkwellBaseURL
			.appendingPathComponent("feeds/\(feedID)/entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "since", value: sinceString),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, credentials: credentials)

		let (response, entries) = try await send(request: request, resultType: [FeedbinEntry].self)
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		return (entries, pagingInfo.nextPage)
	}

	func retrieveEntries() async throws -> ([FeedbinEntry]?, String?, Date?, Int?) {
		let since: Date = {
			if let lastArticleFetch = accountSettings?.lastArticleFetchStartTime {
				if let lastBackdateStartTime {
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
		let url = inkwellBaseURL
			.appendingPathComponent("entries.json")
			.appendingQueryItems([
				URLQueryItem(name: "since", value: sinceString),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "mode", value: "extended")
			])
		let request = URLRequest(url: url!, credentials: credentials)

		let (response, entries) = try await send(request: request, resultType: [FeedbinEntry].self)
		let dateInfo = HTTPDateInfo(urlResponse: response)
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		let lastPageNumber = extractPageNumber(link: pagingInfo.lastPage)
		return (entries, pagingInfo.nextPage, dateInfo?.date, lastPageNumber)
	}

	func retrieveEntries(page: String) async throws -> ([FeedbinEntry]?, String?) {
		guard let url = URL(string: page) else {
			return (nil, nil)
		}

		let request = URLRequest(url: url, credentials: credentials)
		let (response, entries) = try await send(request: request, resultType: [FeedbinEntry].self)
		let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
		return (entries, pagingInfo.nextPage)
	}

	func retrieveUnreadEntries() async throws -> [Int]? {
		let callURL = inkwellBaseURL.appendingPathComponent("unread_entries.json")
		let conditionalGet = accountSettings?.conditionalGetInfo(for: ConditionalGetKeys.unreadEntries)
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		let (response, unreadEntries) = try await send(request: request, resultType: [Int].self)
		storeConditionalGet(key: ConditionalGetKeys.unreadEntries, headers: response.allHeaderFields)
		return unreadEntries
	}

	func createUnreadEntries(entries: [Int]) async throws {
		let callURL = inkwellBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinUnreadEntry(unreadEntries: entries)

		try await send(request: request, method: HTTPMethod.post, payload: payload)
	}

	func deleteUnreadEntries(entries: [Int]) async throws {
		let callURL = inkwellBaseURL.appendingPathComponent("unread_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinUnreadEntry(unreadEntries: entries)

		try await send(request: request, method: HTTPMethod.delete, payload: payload)
	}

	func retrieveStarredEntries() async throws -> [Int]? {
		let callURL = inkwellBaseURL.appendingPathComponent("starred_entries.json")
		let conditionalGet = accountSettings?.conditionalGetInfo(for: ConditionalGetKeys.starredEntries)
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		let (response, starredEntries) = try await send(request: request, resultType: [Int].self)
		storeConditionalGet(key: ConditionalGetKeys.starredEntries, headers: response.allHeaderFields)
		return starredEntries
	}

	func createStarredEntries(entries: [Int]) async throws {
		let callURL = inkwellBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinStarredEntry(starredEntries: entries)

		try await send(request: request, method: HTTPMethod.post, payload: payload)
	}

	func deleteStarredEntries(entries: [Int]) async throws {
		let callURL = inkwellBaseURL.appendingPathComponent("starred_entries.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinStarredEntry(starredEntries: entries)

		try await send(request: request, method: HTTPMethod.delete, payload: payload)
	}
}

private extension InkwellAPICaller {
	func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?) {
		try await sendWithTokenRefresh(request: request) { request in
			try await transport.send(request: request)
		}
	}

	func send<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type) async throws -> (HTTPURLResponse, R?) {
		try await sendWithTokenRefresh(request: request) { request in
			try await transport.send(request: request, resultType: resultType)
		}
	}

	func send(request: URLRequest, method: String) async throws {
		_ = try await sendWithTokenRefresh(request: request) { request in
			try await transport.send(request: request, method: method)
			return true
		}
	}

	func send<P: Encodable & Sendable>(request: URLRequest, method: String, payload: P) async throws {
		_ = try await sendWithTokenRefresh(request: request) { request in
			try await transport.send(request: request, method: method, payload: payload)
			return true
		}
	}

	func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?) {
		try await sendWithTokenRefresh(request: request) { request in
			try await transport.send(request: request, method: method, payload: payload)
		}
	}

	func sendWithTokenRefresh<T>(request: URLRequest, operation: (URLRequest) async throws -> T) async throws -> T {
		if suspended {
			throw TransportError.suspended
		}

		do {
			return try await operation(request)
		} catch {
			guard shouldRefreshCredentials(for: error) else {
				throw error
			}

			try await refreshCredentials()

			var retryRequest = request
			if let credentials {
				retryRequest.setValue("Bearer \(credentials.secret)", forHTTPHeaderField: HTTPRequestHeader.authorization)
			}

			return try await operation(retryRequest)
		}
	}

	func shouldRefreshCredentials(for error: Error) -> Bool {
		guard case TransportError.httpError(let status) = error else {
			return false
		}
		return status == HTTPResponseCode.unauthorized || status == HTTPResponseCode.forbidden
	}

	func refreshCredentials() async throws {
		guard let credentials else {
			throw CredentialsError.missingAccessToken
		}

		let response = try await verifyAccessToken(credentials.secret)
		guard response.hasInkwell else {
			throw InkwellAccountError.inkwellNotEnabled
		}

		let refreshedCredentials = Credentials(type: .bearerAccessToken, username: response.username, secret: response.token)
		if let delegate {
			try delegate.inkwellAPICaller(self, store: refreshedCredentials)
		} else {
			self.credentials = refreshedCredentials
		}
	}

	func storeConditionalGet(key: String, headers: [AnyHashable: Any]) {
		accountSettings?.setConditionalGetInfo(HTTPConditionalGetInfo(headers: headers), for: key)
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
