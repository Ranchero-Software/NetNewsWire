//
//  NewsBlurAPICaller+Internal.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-21.
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

// MARK: - Interact with endpoints

extension NewsBlurAPICaller {
	// GET endpoint, discard response
	func requestData(
			endpoint: String,
			completion: @escaping (Result<Void, Error>) -> Void
	) {
		let callURL = baseURL.appendingPathComponent(endpoint)

		requestData(callURL: callURL, completion: completion)
	}

	// GET endpoint
	func requestData<R: Decodable>(
			endpoint: String,
			resultType: R.Type,
			dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601,
			keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
			completion: @escaping (Result<(HTTPURLResponse, R?), Error>) -> Void
	) {
		let callURL = baseURL.appendingPathComponent(endpoint)

		requestData(
				callURL: callURL,
				resultType: resultType,
				dateDecoding: dateDecoding,
				keyDecoding: keyDecoding,
				completion: completion
		)
	}

	// POST to endpoint, discard response
	func sendUpdates(
			endpoint: String,
			payload: NewsBlurDataConvertible,
			completion: @escaping (Result<Void, Error>) -> Void
	) {
		let callURL = baseURL.appendingPathComponent(endpoint)

		sendUpdates(callURL: callURL, payload: payload, completion: completion)
	}

	// POST to endpoint
	func sendUpdates<R: Decodable>(
			endpoint: String,
			payload: NewsBlurDataConvertible,
			resultType: R.Type,
			dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601,
			keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
			completion: @escaping (Result<(HTTPURLResponse, R?), Error>) -> Void
	) {
		let callURL = baseURL.appendingPathComponent(endpoint)

		sendUpdates(
				callURL: callURL,
				payload: payload,
				resultType: resultType,
				dateDecoding: dateDecoding,
				keyDecoding: keyDecoding,
				completion: completion
		)
	}
}

// MARK: - Interact with URLs

extension NewsBlurAPICaller {
	// GET URL with params, discard response
	func requestData(
			callURL: URL?,
			completion: @escaping (Result<Void, Error>) -> Void
	) {
		guard let callURL = callURL else {
			completion(.failure(TransportError.noURL))
			return
		}

		let request = URLRequest(url: callURL, credentials: credentials)

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

	// GET URL with params
	func requestData<R: Decodable>(
			callURL: URL?,
			resultType: R.Type,
			dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601,
			keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
			completion: @escaping (Result<(HTTPURLResponse, R?), Error>) -> Void
	) {
		guard let callURL = callURL else {
			completion(.failure(TransportError.noURL))
			return
		}

		let request = URLRequest(url: callURL, credentials: credentials)

		transport.send(
				request: request,
				resultType: resultType,
				dateDecoding: dateDecoding,
				keyDecoding: keyDecoding
		) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success(let response):
				completion(.success(response))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	// POST to URL with params, discard response
	func sendUpdates(
			callURL: URL?,
			payload: NewsBlurDataConvertible,
			completion: @escaping (Result<Void, Error>) -> Void
	) {
		guard let callURL = callURL else {
			completion(.failure(TransportError.noURL))
			return
		}

		var request = URLRequest(url: callURL, credentials: credentials)
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: HTTPRequestHeader.contentType)
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

	// POST to URL with params
	func sendUpdates<R: Decodable>(
			callURL: URL?,
			payload: NewsBlurDataConvertible,
			resultType: R.Type,
			dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601,
			keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
			completion: @escaping (Result<(HTTPURLResponse, R?), Error>) -> Void
	) {
		guard let callURL = callURL else {
			completion(.failure(TransportError.noURL))
			return
		}

		guard let data = payload.asData else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		var request = URLRequest(url: callURL, credentials: credentials)
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: HTTPRequestHeader.contentType)

		transport.send(
				request: request,
				method: HTTPMethod.post,
				data: data,
				resultType: resultType,
				dateDecoding: dateDecoding,
				keyDecoding: keyDecoding
		) { result in
			if self.suspended {
				completion(.failure(TransportError.suspended))
				return
			}

			switch result {
			case .success(let response):
				completion(.success(response))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
}
