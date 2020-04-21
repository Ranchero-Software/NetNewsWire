//
//  NewsBlurAPICaller.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class NewsBlurAPICaller: NSObject {
	static let SessionIdCookie = "newsblur_sessionid"

	let baseURL = URL(string: "https://www.newsblur.com/")!
	var transport: Transport!
	var suspended = false

	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?

	init(transport: Transport!) {
		super.init()
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

	func validateCredentials(completion: @escaping (Result<Credentials?, Error>) -> Void) {
		requestData(endpoint: "api/login", resultType: NewsBlurLoginResponse.self) { result in
			switch result {
			case .success((let response, let payload)):
				guard let url = response.url, let headerFields = response.allHeaderFields as? [String: String], payload?.code != -1 else {
					let error = payload?.errors?.username ?? payload?.errors?.others
					if let message = error?.first {
						completion(.failure(NewsBlurError.general(message: message)))
					} else {
						completion(.failure(NewsBlurError.unknown))
					}
					return
				}

				guard let username = self.credentials?.username else {
					completion(.failure(NewsBlurError.unknown))
					return
				}

				let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
				for cookie in cookies where cookie.name == Self.SessionIdCookie {
					let credentials = Credentials(type: .newsBlurSessionId, username: username, secret: cookie.value)
					completion(.success(credentials))
					return
				}

				completion(.failure(NewsBlurError.general(message: "Failed to retrieve session")))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func logout(completion: @escaping (Result<Void, Error>) -> Void) {
		requestData(endpoint: "api/logout", completion: completion)
	}

	func retrieveFeeds(completion: @escaping (Result<([NewsBlurFeed]?, [NewsBlurFolder]?), Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent("reader/feeds")
				.appendingQueryItems([
					URLQueryItem(name: "flat", value: "true"),
					URLQueryItem(name: "update_counts", value: "false"),
				])

		requestData(callURL: url, resultType: NewsBlurFeedsResponse.self) { result in
			switch result {
			case .success((_, let payload)):
				completion(.success((payload?.feeds, payload?.folders)))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func retrieveStoryHashes(endpoint: String, completion: @escaping (Result<[NewsBlurStoryHash]?, Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent(endpoint)
				.appendingQueryItems([
					URLQueryItem(name: "include_timestamps", value: "true"),
				])

		requestData(
				callURL: url,
				resultType: NewsBlurStoryHashesResponse.self,
				dateDecoding: .secondsSince1970
		) { result in
			switch result {
			case .success((_, let payload)):
				let hashes = payload?.unread ?? payload?.starred
				completion(.success(hashes))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func retrieveUnreadStoryHashes(completion: @escaping (Result<[NewsBlurStoryHash]?, Error>) -> Void) {
		retrieveStoryHashes(
				endpoint: "reader/unread_story_hashes", 
				completion: completion
		)
	}

	func retrieveStarredStoryHashes(completion: @escaping (Result<[NewsBlurStoryHash]?, Error>) -> Void) {
		retrieveStoryHashes(
				endpoint: "reader/starred_story_hashes", 
				completion: completion
		)
	}

	func retrieveStories(feedID: String, page: Int, completion: @escaping (Result<([NewsBlurStory]?, Date?), Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent("reader/feed/\(feedID)")
				.appendingQueryItems([
					URLQueryItem(name: "page", value: String(page)),
					URLQueryItem(name: "order", value: "newest"),
					URLQueryItem(name: "read_filter", value: "all"),
					URLQueryItem(name: "include_hidden", value: "true"),
					URLQueryItem(name: "include_story_content", value: "true"),
				])

		requestData(callURL: url, resultType: NewsBlurStoriesResponse.self) { result in
			switch result {
			case .success(let (response, payload)):
				completion(.success((payload?.stories, HTTPDateInfo(urlResponse: response)?.date)))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func retrieveStories(hashes: [NewsBlurStoryHash], completion: @escaping (Result<([NewsBlurStory]?, Date?), Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent("reader/river_stories")
				.appendingQueryItem(.init(name: "include_hidden", value: "true"))?
				.appendingQueryItems(hashes.map {
					URLQueryItem(name: "h", value: $0.hash)
				})

		requestData(callURL: url, resultType: NewsBlurStoriesResponse.self) { result in
			switch result {
			case .success(let (response, payload)):
				completion(.success((payload?.stories, HTTPDateInfo(urlResponse: response)?.date)))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func markAsUnread(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/mark_story_hash_as_unread", 
				payload: NewsBlurStoryStatusChange(hashes: hashes),
				completion: completion
		)
	}

	func markAsRead(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/mark_story_hashes_as_read", 
				payload: NewsBlurStoryStatusChange(hashes: hashes),
				completion: completion
		)
	}

	func star(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/mark_story_hash_as_starred", 
				payload: NewsBlurStoryStatusChange(hashes: hashes),
				completion: completion
		)
	}

	func unstar(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/mark_story_hash_as_unstarred", 
				payload: NewsBlurStoryStatusChange(hashes: hashes),
				completion: completion
		)
	}

	func addFolder(named name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/add_folder", 
				payload: NewsBlurFolderChange.add(name),
				completion: completion
		)
	}

	func renameFolder(with folder: String, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/rename_folder", 
				payload: NewsBlurFolderChange.rename(folder, name),
				completion: completion
		)
	}

	func removeFolder(named name: String, feedIDs: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/delete_folder", 
				payload: NewsBlurFolderChange.delete(name, feedIDs),
				completion: completion
		)
	}

	func addURL(_ url: String, folder: String?, completion: @escaping (Result<NewsBlurFeed?, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/add_url", 
				payload: NewsBlurFeedChange.add(url, folder),
				resultType: NewsBlurAddURLResponse.self
		) { result in
			switch result {
			case .success((_, let payload)):
				completion(.success(payload?.feed))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func renameFeed(feedID: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/rename_feed", 
				payload: NewsBlurFeedChange.rename(feedID, newName)
		) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func deleteFeed(feedID: String, folder: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/delete_feed",
				payload: NewsBlurFeedChange.delete(feedID, folder)
		) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func moveFeed(feedID: String, from: String?, to: String?, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(
				endpoint: "reader/move_feed_to_folder",
				payload: NewsBlurFeedChange.move(feedID, from, to)
		) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}
