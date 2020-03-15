//
//  NewsBlurAPICaller.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol NewsBlurDataConvertible {
	var asData: Data? { get }
}

enum NewsBlurError: LocalizedError {
	case general(message: String)
	case invalidParameter
	case unknown

	var errorDescription: String? {
		switch self {
		case .general(let message):
			return message
		case .invalidParameter:
			return "There was an invalid parameter passed"
		case .unknown:
			return "An unknown error occurred"
		}
	}
}

final class NewsBlurAPICaller: NSObject {
	static let SessionIdCookie = "newsblur_sessionid"

	private let baseURL = URL(string: "https://www.newsblur.com/")!
	private var transport: Transport!
	private var suspended = false

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
		let url = baseURL.appendingPathComponent("api/login")
		let request = URLRequest(url: url, credentials: credentials)

		transport.send(request: request, resultType: NewsBlurLoginResponse.self) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success(let response, let payload):
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
		let url = baseURL.appendingPathComponent("api/logout")
		let request = URLRequest(url: url, credentials: credentials)

		transport.send(request: request) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func retrieveFeeds(completion: @escaping (Result<([NewsBlurFeed]?, [NewsBlurFolder]?), Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent("reader/feeds")
				.appendingQueryItems([
					URLQueryItem(name: "flat", value: "true"),
					URLQueryItem(name: "update_counts", value: "false"),
				])

		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}

		let request = URLRequest(url: callURL, credentials: credentials)
		transport.send(request: request, resultType: NewsBlurFeedsResponse.self) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success((_, let payload)):
				completion(.success((payload?.feeds, payload?.folders)))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func retrieveUnreadStoryHashes(completion: @escaping (Result<[NewsBlurStoryHash]?, Error>) -> Void) {
		retrieveStoryHashes(endpoint: "reader/unread_story_hashes", completion: completion)
	}

	func retrieveStarredStoryHashes(completion: @escaping (Result<[NewsBlurStoryHash]?, Error>) -> Void) {
		retrieveStoryHashes(endpoint: "reader/starred_story_hashes", completion: completion)
	}

	func retrieveStories(hashes: [NewsBlurStoryHash], completion: @escaping (Result<[NewsBlurStory]?, Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent("reader/river_stories")
				.appendingQueryItem(.init(name: "include_hidden", value: "true"))?
				.appendingQueryItems(hashes.map {
					URLQueryItem(name: "h", value: $0.hash)
				})

		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}

		let request = URLRequest(url: callURL, credentials: credentials)
		transport.send(request: request, resultType: NewsBlurStoriesResponse.self) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success((_, let payload)):
				completion(.success(payload?.stories))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func markAsUnread(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/mark_story_hash_as_unread", payload: NewsBlurStoryStatusChange(hashes: hashes), completion: completion)
	}

	func markAsRead(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/mark_story_hashes_as_read", payload: NewsBlurStoryStatusChange(hashes: hashes), completion: completion)
	}

	func star(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/mark_story_hash_as_starred", payload: NewsBlurStoryStatusChange(hashes: hashes), completion: completion)
	}

	func unstar(hashes: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/mark_story_hash_as_unstarred", payload: NewsBlurStoryStatusChange(hashes: hashes), completion: completion)
	}

	func addFolder(named name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/add_folder", payload: NewsBlurFolderChange.add(name), completion: completion)
	}

	func renameFolder(with folder: String, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/rename_folder", payload: NewsBlurFolderChange.rename(folder, name), completion: completion)
	}

	func removeFolder(named name: String, feedIDs: [String], completion: @escaping (Result<Void, Error>) -> Void) {
		sendUpdates(endpoint: "reader/delete_folder", payload: NewsBlurFolderChange.delete(name, feedIDs), completion: completion)
	}
}

extension NewsBlurAPICaller {
	private func retrieveStoryHashes(endpoint: String, completion: @escaping (Result<[NewsBlurStoryHash]?, Error>) -> Void) {
		let url = baseURL
				.appendingPathComponent(endpoint)
				.appendingQueryItems([
					URLQueryItem(name: "include_timestamps", value: "true"),
				])

		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}

		let request = URLRequest(url: callURL, credentials: credentials)
		transport.send(request: request, resultType: NewsBlurStoryHashesResponse.self, dateDecoding: .secondsSince1970) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success((_, let payload)):
				let hashes = payload?.unread ?? payload?.starred
				completion(.success(hashes?.values.flatMap { $0 }))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	private func sendUpdates(endpoint: String, payload: NewsBlurDataConvertible, completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = baseURL.appendingPathComponent(endpoint)

		var request = URLRequest(url: callURL, credentials: credentials)
		request.httpBody = payload.asData
		transport.send(request: request, method: HTTPMethod.post) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}
