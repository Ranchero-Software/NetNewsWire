//
//  NewsBlurAPICaller.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Secrets

@MainActor public final class NewsBlurAPICaller: NSObject {
	
	public static let sessionIDCookieKey = "newsblur_sessionid"

	let baseURL = URL(string: "https://www.newsblur.com/")!
	var transport: Transport!
	var isSuspended = false

	public var credentials: Credentials?

	public init(transport: Transport!) {
		super.init()
		self.transport = transport
	}

	/// Cancels all pending requests rejects any that come in later
	public func suspend() {
		transport.cancelAll()
		isSuspended = true
	}

	public func resume() {
		isSuspended = false
	}

	public func validateCredentials() async throws -> Credentials? {

		let (response, payload) = try await requestData(endpoint: "api/login", resultType: NewsBlurLoginResponse.self)

		guard let url = response.url, let headerFields = response.allHeaderFields as? [String: String], payload?.code != -1 else {
			let error = payload?.errors?.username ?? payload?.errors?.others
			if let message = error?.first {
				throw NewsBlurError.general(message: message)
			}
			throw NewsBlurError.unknown
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

	public func logout() async throws {

		try await requestData(endpoint: "api/logout")
	}

	public func retrieveFeeds() async throws -> ([NewsBlurFeed]?, [NewsBlurFolder]?) {

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

	public func retrieveUnreadStoryHashes() async throws -> Set<NewsBlurStoryHash>? {

		return try await retrieveStoryHashes(endpoint: "reader/unread_story_hashes")
	}

	public func retrieveStarredStoryHashes() async throws -> Set<NewsBlurStoryHash>? {

		return try await retrieveStoryHashes(endpoint: "reader/starred_story_hashes")
	}

	public func retrieveStories(feedID: String, page: Int) async throws -> ([NewsBlurStory]?, Date?) {

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

	public func retrieveStories(hashes: [NewsBlurStoryHash]) async throws -> ([NewsBlurStory]?, Date?) {

		let url: URL! = baseURL
			.appendingPathComponent("reader/river_stories")
			.appendingQueryItem(.init(name: "include_hidden", value: "false"))?
			.appendingQueryItems(hashes.map {
				URLQueryItem(name: "h", value: $0.hash)
			})

		let (response, payload) = try await requestData(callURL: url, resultType: NewsBlurStoriesResponse.self)
		return (payload?.stories, HTTPDateInfo(urlResponse: response)?.date)
	}

	public func markAsUnread(hashes: Set<String>) async throws {

		try await sendUpdates(endpoint: "reader/mark_story_hash_as_unread", payload: NewsBlurStoryStatusChange(hashes: hashes))
	}

	public func markAsRead(hashes: Set<String>) async throws {

		try await sendUpdates(endpoint: "reader/mark_story_hashes_as_read", payload: NewsBlurStoryStatusChange(hashes: hashes))
	}

	public func star(hashes: Set<String>) async throws {

		try await sendUpdates(endpoint: "reader/mark_story_hash_as_starred", payload: NewsBlurStoryStatusChange(hashes: hashes))
	}

	public func unstar(hashes: Set<String>) async throws {

		try await sendUpdates(endpoint: "reader/mark_story_hash_as_unstarred", payload: NewsBlurStoryStatusChange(hashes: hashes))
	}

	public func addFolder(named name: String) async throws {

		try await sendUpdates(endpoint: "reader/add_folder", payload: NewsBlurFolderChange.add(name))
	}

	public func renameFolder(with folder: String, to name: String) async throws {

		try await sendUpdates(endpoint: "reader/rename_folder", payload: NewsBlurFolderChange.rename(folder, name))
	}

	public func removeFolder(named name: String, feedIDs: [String]) async throws {

		try await sendUpdates(endpoint: "reader/delete_folder", payload: NewsBlurFolderChange.delete(name, feedIDs))
	}

	public func addURL(_ url: String, folder: String?) async throws -> NewsBlurFeed? {

		let (_, payload) = try await sendUpdates(endpoint: "reader/add_url", payload: NewsBlurFeedChange.add(url, folder), resultType: NewsBlurAddURLResponse.self)
		return payload?.feed
	}

	public func renameFeed(feedID: String, newName: String) async throws {

		try await sendUpdates(endpoint: "reader/rename_feed", payload: NewsBlurFeedChange.rename(feedID, newName))
	}

	public func deleteFeed(feedID: String, folder: String? = nil) async throws {

		try await sendUpdates(endpoint: "reader/delete_feed", payload: NewsBlurFeedChange.delete(feedID, folder))
	}

	public func moveFeed(feedID: String, from: String?, to: String?) async throws {

		try await sendUpdates(endpoint: "reader/move_feed_to_folder", payload: NewsBlurFeedChange.move(feedID, from, to))
	}
}
