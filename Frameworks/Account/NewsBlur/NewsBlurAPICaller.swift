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
			case .success(_, let payload):
				guard payload?.code != -1 else {
					let error = payload?.errors?.username ?? payload?.errors?.others
					if let message = error?.first {
						completion(.failure(NewsBlurError.general(message: message)))
					} else {
						completion(.failure(NewsBlurError.general(message: "Failed to log in")))
					}
					return
				}
				completion(.success(self.credentials))
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
}
