//
//  NewsBlurAPICaller.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

enum NewsBlurError: LocalizedError {
	case general(message: String)

	var errorDescription: String? {
		switch self {
		case .general(let message):
			return message
		}
	}
}

final class NewsBlurAPICaller: NSObject {
	static let SessionIdCookie = "newsblur_sessionid"

	private let baseURL = URL(string: "https://www.newsblur.com/")!
	private var transport: Transport!

	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?

	init(transport: Transport!) {
		super.init()
		self.transport = transport
	}

	func validateCredentials(completion: @escaping (Result<Credentials?, Error>) -> Void) {
		let url = baseURL.appendingPathComponent("api/login")
		let request = URLRequest(url: url, credentials: credentials)

		transport.send(request: request, resultType: NewsBlurLoginResponse.self) { result in
			switch result {
			case .success(let response, let payload):
				guard let url = response.url, let headerFields = response.allHeaderFields as? [String: String], payload?.code != -1 else {
					let error = payload?.errors?.username ?? payload?.errors?.others
					if let message = error?.first {
						completion(.failure(NewsBlurError.general(message: message)))
					} else {
						completion(.failure(NewsBlurError.general(message: "Failed to log in")))
					}
					return
				}

				guard let username = self.credentials?.username else {
					completion(.failure(NewsBlurError.general(message: "Failed to log in")))
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
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func retrieveSubscriptions(completion: @escaping (Result<[NewsBlurSubscription]?, Error>) -> Void) {
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
			switch result {
			case .success(let (response, payload)):
				print(payload)
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}
