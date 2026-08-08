//
//  MinifluxCaller.swift
//  Account
//
//  Created by Ingmar Stein on 6/18/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSWeb
import Secrets

@MainActor final class MinifluxCaller {

	private let session = URLSession.webservice
	private let logger: Logger

	var accountSettings: AccountSettings?
	var credentials: Credentials?

	/// Set to `true` when the Miniflux server is v2.3.2+ and supports `/v1/entries/ids`.
	var supportsEntryIDsEndpoint = false

	// Cached category list for mapping between category IDs and names.
	private var categories: [MinifluxCategory]?

	init(logger: Logger) {
		self.logger = logger
	}

	func cancelAll() {
		session.cancelAll()
	}

	// MARK: - API Base URL

	private var apiBaseURL: URL? {
		guard let endpointURL = accountSettings?.endpointURL else {
			return nil
		}
		return endpointURL.appendingPathComponent("v1")
	}

	// MARK: - Authentication

	private func authenticatedRequest(url: URL, method: String? = nil, body: Data? = nil) throws -> URLRequest {
		guard let credentials, credentials.type == .minifluxAPIKey else {
			throw CredentialsError.missingAccessToken
		}

		var request = URLRequest(url: url)
		request.setValue(credentials.secret, forHTTPHeaderField: "X-Auth-Token")

		if let method {
			request.httpMethod = method
		}

		if let body {
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			request.httpBody = body
		}

		return request
	}

	// MARK: - Validation

	func validateCredentials(endpoint: URL) async throws -> Credentials? {
		guard let credentials else {
			throw CredentialsError.missingAccessToken
		}

		let baseURL = endpoint.appendingPathComponent("v1")
		let url = baseURL.appendingPathComponent("me")

		var request = URLRequest(url: url)
		request.setValue(credentials.secret, forHTTPHeaderField: "X-Auth-Token")

		do {
			let (response, _) = try await session.send(request: request)
			guard response.statusCode == 200 else {
				if response.statusCode == 401 || response.statusCode == 403 {
					return nil
				}
				throw AccountError.invalidResponse
			}
			return credentials
		} catch {
			if let webserviceError = error as? WebserviceError, case .httpError(let code) = webserviceError, code == 404 {
				throw AccountError.urlNotFound
			}
			throw error
		}
	}

	// MARK: - Feeds

	// MARK: - Version

	func retrieveVersion() async throws -> MinifluxVersion? {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("version")
		let request = try authenticatedRequest(url: url)

		let (_, version) = try await session.send(request: request, resultType: MinifluxVersion.self)
		return version
	}


	func retrieveFeeds() async throws -> [MinifluxFeed]? {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("feeds")
		let request = try authenticatedRequest(url: url)

		let (_, feeds) = try await session.send(request: request, resultType: [MinifluxFeed].self)
		return feeds
	}

	func createFeed(url feedURL: String, categoryID: Int?) async throws -> Int {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("feeds")

		struct CreateFeedBody: Encodable {
			let feedURL: String
			let categoryID: Int?

			enum CodingKeys: String, CodingKey {
				case feedURL = "feed_url"
				case categoryID = "category_id"
			}
		}

		let body = CreateFeedBody(feedURL: feedURL, categoryID: categoryID)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: url, method: "POST", body: bodyData)

		let (response, result) = try await session.send(request: request, resultType: MinifluxCreateFeedResult.self)

		guard response.statusCode == 201, let feedID = result?.feedID else {
			throw AccountError.invalidResponse
		}

		// Refresh the newly created feed to fetch its articles
		let refreshURL = baseURL.appendingPathComponent("feeds").appendingPathComponent(String(feedID)).appendingPathComponent("refresh")
		let refreshRequest = try authenticatedRequest(url: refreshURL, method: "PUT")
		_ = try await session.send(request: refreshRequest)

		return feedID
	}

	func deleteFeed(feedID: Int) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("feeds").appendingPathComponent(String(feedID))
		let request = try authenticatedRequest(url: url, method: "DELETE")

		let (response, _) = try await session.send(request: request)
		guard response.statusCode == 204 else {
			throw AccountError.invalidResponse
		}
	}

	func renameFeed(feedID: Int, name: String) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("feeds").appendingPathComponent(String(feedID))

		struct RenameFeedBody: Encodable {
			let title: String
		}

		let body = RenameFeedBody(title: name)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: url, method: "PUT", body: bodyData)
		_ = try await session.send(request: request)
	}

	func moveFeed(feedID: Int, categoryID: Int) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("feeds").appendingPathComponent(String(feedID))

		struct MoveFeedBody: Encodable {
			let categoryID: Int

			enum CodingKeys: String, CodingKey {
				case categoryID = "category_id"
			}
		}

		let body = MoveFeedBody(categoryID: categoryID)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: url, method: "PUT", body: bodyData)
		_ = try await session.send(request: request)
	}

	func refreshAllFeeds() async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("feeds").appendingPathComponent("refresh")
		let request = try authenticatedRequest(url: url, method: "PUT")
		_ = try await session.send(request: request)
	}

	// MARK: - Categories

	func retrieveCategories() async throws -> [MinifluxCategory]? {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("categories")
		let request = try authenticatedRequest(url: url)

		let (_, categories) = try await session.send(request: request, resultType: [MinifluxCategory].self)
		self.categories = categories
		return categories
	}

	func createCategory(name: String) async throws -> Int {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("categories")

		struct CreateCategoryBody: Encodable {
			let title: String
		}

		let body = CreateCategoryBody(title: name)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: url, method: "POST", body: bodyData)

		let (response, result) = try await session.send(request: request, resultType: MinifluxCreateCategoryResult.self)

		guard response.statusCode == 201, let id = result?.id else {
			throw AccountError.invalidResponse
		}

		// Invalidate category cache
		self.categories = nil

		return id
	}

	func deleteCategory(id: Int) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("categories").appendingPathComponent(String(id))
		let request = try authenticatedRequest(url: url, method: "DELETE")

		let (response, _) = try await session.send(request: request)
		guard response.statusCode == 204 else {
			throw AccountError.invalidResponse
		}

		self.categories = nil
	}

	func renameCategory(id: Int, name: String) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("categories").appendingPathComponent(String(id))

		struct RenameCategoryBody: Encodable {
			let title: String
		}

		let body = RenameCategoryBody(title: name)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: url, method: "PUT", body: bodyData)
		_ = try await session.send(request: request)

		self.categories = nil
	}

	// MARK: - Entries

	func retrieveEntries(status: String? = nil, offset: Int = 0, limit: Int = 100) async throws -> MinifluxEntriesResult? {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		var urlComponents = URLComponents(url: baseURL.appendingPathComponent("entries"), resolvingAgainstBaseURL: false)
		var queryItems = [
			URLQueryItem(name: "offset", value: String(offset)),
			URLQueryItem(name: "limit", value: String(limit)),
			URLQueryItem(name: "direction", value: "desc"),
			URLQueryItem(name: "order", value: "published_at")
		]
		if let status {
			queryItems.append(URLQueryItem(name: "status", value: status))
		}
		urlComponents?.queryItems = queryItems

		guard let url = urlComponents?.url else {
			throw WebserviceError.noURL
		}

		let request = try authenticatedRequest(url: url)
		let (_, result) = try await session.send(request: request, resultType: MinifluxEntriesResult.self)
		return result
	}

	enum EntryListType {
		case all
		case unread
		case starred
	}

	func retrieveEntryIDs(type: EntryListType = .all) async throws -> [Int] {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		// Use the more efficient /v1/entries/ids endpoint when available (v2.3.2+).
		if supportsEntryIDsEndpoint {
			var urlComponents = URLComponents(url: baseURL.appendingPathComponent("entries").appendingPathComponent("ids"), resolvingAgainstBaseURL: false)
			var queryItems: [URLQueryItem] = []
			switch type {
			case .all:
				break
			case .unread:
				queryItems.append(URLQueryItem(name: "status", value: "unread"))
			case .starred:
				queryItems.append(URLQueryItem(name: "starred", value: "true"))
			}
			urlComponents?.queryItems = queryItems

			guard let url = urlComponents?.url else {
				throw WebserviceError.noURL
			}

			let request = try authenticatedRequest(url: url)
			let (_, result) = try await session.send(request: request, resultType: MinifluxEntryIDsResult.self)
			return result?.entryIDs ?? []
		}

		// Fallback: paginate through /v1/entries (available since v2.0).
		var allIDs: [Int] = []
		var offset = 0
		let pageSize = 1000

		while true {
			var urlComponents = URLComponents(url: baseURL.appendingPathComponent("entries"), resolvingAgainstBaseURL: false)
			var queryItems: [URLQueryItem] = [
				URLQueryItem(name: "offset", value: String(offset)),
				URLQueryItem(name: "limit", value: String(pageSize)),
				URLQueryItem(name: "direction", value: "asc")
			]
			switch type {
			case .all:
				break
			case .unread:
				queryItems.append(URLQueryItem(name: "status", value: "unread"))
			case .starred:
				queryItems.append(URLQueryItem(name: "starred", value: "true"))
			}
			urlComponents?.queryItems = queryItems

			guard let url = urlComponents?.url else {
				throw WebserviceError.noURL
			}

			let request = try authenticatedRequest(url: url)
			let (_, result) = try await session.send(request: request, resultType: MinifluxEntriesResult.self)

			guard let result else {
				return allIDs
			}

			let pageIDs = result.entries.map { $0.id }
			allIDs.append(contentsOf: pageIDs)

			if pageIDs.count < pageSize || result.total <= allIDs.count {
				return allIDs
			}

			offset += pageSize
		}
	}

	func retrieveEntries(articleIDs: [Int]) async throws -> [MinifluxEntry]? {
		guard !articleIDs.isEmpty else {
			return []
		}

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		// Fetch entries in batches. The entries endpoint supports filtering
		// but for individual IDs we fetch them one at a time up to a batch limit.
		// We use the "after_entry_id" approach for efficiency.
		// For simplicity, fetch entries one by one and collect.
		var entries: [MinifluxEntry] = []

		// Fetch entries in chunks using a query approach
		for idBatch in articleIDs.chunked(into: 100) {
			var urlComponents = URLComponents(url: baseURL.appendingPathComponent("entries"), resolvingAgainstBaseURL: false)

			// Build query with status filter to get all then filter locally.
			// Miniflux doesn't have a direct "get by IDs" endpoint,
			// but we can use the search parameter with IDs or fetch individually.
			// For efficiency, we fetch by searching for individual entries.
			let queryItems = [
				URLQueryItem(name: "limit", value: String(idBatch.count * 2)), // extra margin
				URLQueryItem(name: "direction", value: "desc")
			]
			urlComponents?.queryItems = queryItems

			guard let url = urlComponents?.url else {
				throw WebserviceError.noURL
			}

			let request = try authenticatedRequest(url: url)
			let (_, result) = try await session.send(request: request, resultType: MinifluxEntriesResult.self)

			if let fetchedEntries = result?.entries {
				let matchingEntries = fetchedEntries.filter { idBatch.contains($0.id) }
				entries.append(contentsOf: matchingEntries)
			}
		}

		return entries
	}

	func markEntriesRead(entryIDs: [Int]) async throws {
		try await updateEntryStatus(entryIDs: entryIDs, status: "read")
	}

	func markEntriesUnread(entryIDs: [Int]) async throws {
		try await updateEntryStatus(entryIDs: entryIDs, status: "unread")
	}

	private func updateEntryStatus(entryIDs: [Int], status: String) async throws {
		guard !entryIDs.isEmpty else {
			return
		}

		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("entries")
		let body = MinifluxBatchEntryUpdate(entryIDs: entryIDs, status: status)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: url, method: "PUT", body: bodyData)
		let (response, _) = try await session.send(request: request)
		guard response.statusCode == 204 else {
			throw AccountError.invalidResponse
		}
	}

	func toggleBookmark(entryID: Int) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("entries").appendingPathComponent(String(entryID)).appendingPathComponent("bookmark")
		let request = try authenticatedRequest(url: url, method: "PUT")
		let (response, _) = try await session.send(request: request)
		guard response.statusCode == 204 else {
			throw AccountError.invalidResponse
		}
	}

	// MARK: - OPML

	func importOPML(opmlData: Data) async throws {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let url = baseURL.appendingPathComponent("import")
		var request = try authenticatedRequest(url: url, method: "POST", body: opmlData)
		request.setValue("text/xml", forHTTPHeaderField: "Content-Type")

		let (response, _) = try await session.send(request: request)
		guard response.statusCode == 201 else {
			throw AccountError.invalidResponse
		}
	}

	// MARK: - Discover

	func discoverFeeds(url: String, username: String? = nil, password: String? = nil) async throws -> [MinifluxDiscoverResult]? {
		guard let baseURL = apiBaseURL else {
			throw CredentialsError.missingEndpointURL
		}

		let apiURL = baseURL.appendingPathComponent("discover")

		struct DiscoverBody: Encodable {
			let url: String
			let username: String?
			let password: String?
		}

		let body = DiscoverBody(url: url, username: username, password: password)
		let bodyData = try JSONEncoder().encode(body)

		let request = try authenticatedRequest(url: apiURL, method: "POST", body: bodyData)
		let (_, results) = try await session.send(request: request, resultType: [MinifluxDiscoverResult].self)
		return results
	}
}
