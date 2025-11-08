//
//  NewsBlurAPICaller.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Secrets

final class NewsBlurAPICaller {
	static let sessionIDCookieKey = "newsblur_sessionid"

	let baseURL = URL(string: "https://www.newsblur.com/")!
	let transport: Transport
	var suspended = false

	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?

	init(transport: Transport!) {
		self.transport = transport
	}

	/// Cancel all pending requests and reject future requests.
	func suspend() {
		transport.cancelAll()
		suspended = true
	}

	func resume() {
		suspended = false
	}

	func validateCredentials() async throws -> Credentials? {
		let (response, payload) = try await requestData(endpoint: "api/login", resultType: NewsBlurLoginResponse.self)

		guard let url = response.url,
			  let headerFields = response.allHeaderFields as? [String: String],
			  payload?.code != -1 else {
			let error = payload?.errors?.username ?? payload?.errors?.others
			if let message = error?.first {
				throw NewsBlurError.general(message: message)
			} else {
				throw NewsBlurError.unknown
			}
		}

		guard let username = self.credentials?.username else {
			throw NewsBlurError.unknown
		}

		let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
		for cookie in cookies where cookie.name == Self.sessionIDCookieKey {
			let credentials = Credentials(type: .newsBlurSessionID, username: username, secret: cookie.value)
			return credentials
		}

		throw NewsBlurError.general(message: "Failed to retrieve session")
	}

	func logout() async throws {
		try await requestData(endpoint: "api/logout")
	}

	func retrieveFeeds() async throws -> ([NewsBlurFeed]?, [NewsBlurFolder]?) {
		let url: URL! = baseURL
			.appendingPathComponent("reader/feeds")
			.appendingQueryItems([
				URLQueryItem(name: "flat", value: "true"),
				URLQueryItem(name: "update_counts", value: "true"),
			])

		let (_, payload) = try await requestData(callURL: url, resultType: NewsBlurFeedsResponse.self)
		return (payload?.feeds, payload?.folders)
	}

	func retrieveStoryHashes(endpoint: String) async throws -> Set<NewsBlurStoryHash>? {
		let url: URL! = baseURL
			.appendingPathComponent(endpoint)
			.appendingQueryItems([
				URLQueryItem(name: "include_timestamps", value: "true"),
			])

		let (_, payload) = try await requestData(callURL: url, resultType: NewsBlurStoryHashesResponse.self, dateDecoding: .secondsSince1970)

		if let hashes = payload?.unread ?? payload?.starred {
			return Set(hashes)
		} else {
			return nil
		}
	}

	func retrieveUnreadStoryHashes() async throws -> Set<NewsBlurStoryHash>? {
		try await retrieveStoryHashes(endpoint: "reader/unread_story_hashes")
	}

	func retrieveStarredStoryHashes() async throws -> Set<NewsBlurStoryHash>? {
		try await retrieveStoryHashes(endpoint: "reader/starred_story_hashes")
	}

	func retrieveStories(feedID: String, page: Int) async throws -> ([NewsBlurStory]?, Date?) {
		let url: URL! = baseURL
			.appendingPathComponent("reader/feed/\(feedID)")
			.appendingQueryItems([
				URLQueryItem(name: "page", value: String(page)),
				URLQueryItem(name: "order", value: "newest"),
				URLQueryItem(name: "read_filter", value: "all"),
				URLQueryItem(name: "include_hidden", value: "false"),
				URLQueryItem(name: "include_story_content", value: "true"),
			])

		let (response, payload) = try await requestData(callURL: url, resultType: NewsBlurStoriesResponse.self)
		return (payload?.stories, HTTPDateInfo(urlResponse: response)?.date)
	}

	func retrieveStories(hashes: [NewsBlurStoryHash]) async throws -> ([NewsBlurStory]?, Date?) {
		let url: URL! = baseURL
			.appendingPathComponent("reader/river_stories")
			.appendingQueryItem(.init(name: "include_hidden", value: "false"))?
			.appendingQueryItems(hashes.map {
				URLQueryItem(name: "h", value: $0.hash)
			})

		let (response, payload) = try await requestData(callURL: url, resultType: NewsBlurStoriesResponse.self)
		return (payload?.stories, HTTPDateInfo(urlResponse: response)?.date)
	}

	func markAsUnread(hashes: Set<String>) async throws {
		try await sendUpdates(endpoint: "reader/mark_story_hash_as_unread",
							  payload: NewsBlurStoryStatusChange(hashes: Array(hashes)))
	}

	func markAsRead(hashes: Set<String>) async throws {
		try await sendUpdates(endpoint: "reader/mark_story_hashes_as_read",
							  payload: NewsBlurStoryStatusChange(hashes: Array(hashes)))
	}

	func star(hashes: Set<String>) async throws {
		try await sendUpdates(endpoint: "reader/mark_story_hash_as_starred",
							  payload: NewsBlurStoryStatusChange(hashes: Array(hashes)))
	}

	func unstar(hashes: Set<String>) async throws {
		try await sendUpdates(endpoint: "reader/mark_story_hash_as_unstarred",
							  payload: NewsBlurStoryStatusChange(hashes: Array(hashes)))
	}

	func addFolder(named name: String) async throws {
		try await sendUpdates(endpoint: "reader/add_folder",
							  payload: NewsBlurFolderChange.add(name))
	}

	func renameFolder(with folder: String, to name: String) async throws {
		try await sendUpdates(endpoint: "reader/rename_folder",
							  payload: NewsBlurFolderChange.rename(folder, name))
	}

	func removeFolder(named name: String, feedIDs: [String]) async throws {
		try await sendUpdates(endpoint: "reader/delete_folder",
							  payload: NewsBlurFolderChange.delete(name, feedIDs))
	}

	func addURL(_ url: String, folder: String?) async throws -> NewsBlurFeed? {
		let (_, payload) = try await sendUpdates(endpoint: "reader/add_url",
												 payload: NewsBlurFeedChange.add(url, folder),
												 resultType: NewsBlurAddURLResponse.self)
		return payload?.feed
	}

	func renameFeed(feedID: String, newName: String) async throws {
		try await sendUpdates(endpoint: "reader/rename_feed",
							  payload: NewsBlurFeedChange.rename(feedID, newName))
	}

	func deleteFeed(feedID: String, folder: String? = nil) async throws {
		try await sendUpdates(endpoint: "reader/delete_feed",
							  payload: NewsBlurFeedChange.delete(feedID, folder))
	}

	func moveFeed(feedID: String, from: String?, to: String?) async throws {
		try await sendUpdates(endpoint: "reader/move_feed_to_folder",
							  payload: NewsBlurFeedChange.move(feedID, from, to))
	}
}
