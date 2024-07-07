//
//  NewsBlurAPICaller+Internal.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-21.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web

public protocol NewsBlurDataConvertible {

	var asData: Data? { get }
}

public enum NewsBlurError: LocalizedError, Sendable {

	case general(message: String)
	case invalidParameter
	case unknown

	public var errorDescription: String? {
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

	/// GET endpoint, discard response
	func requestData(endpoint: String) async throws {

		let callURL = baseURL.appendingPathComponent(endpoint)
		try await requestData(callURL: callURL)
	}

	/// GET endpoint
	func requestData<R: Decodable & Sendable>(endpoint: String, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		let callURL = baseURL.appendingPathComponent(endpoint)
		return try await requestData(callURL: callURL, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
	}

	/// POST to endpoint, discard response
	func sendUpdates(endpoint: String, payload: NewsBlurDataConvertible) async throws {

		let callURL = baseURL.appendingPathComponent(endpoint)
		try await sendUpdates(callURL: callURL, payload: payload)
	}

	/// POST to endpoint
	func sendUpdates<R: Decodable & Sendable>(endpoint: String, payload: NewsBlurDataConvertible, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		let callURL = baseURL.appendingPathComponent(endpoint)
		return try await sendUpdates(callURL: callURL, payload: payload, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
	}
}

// MARK: - Interact with URLs

extension NewsBlurAPICaller {

	/// GET URL with params, discard response
	func requestData(callURL: URL) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		let request = URLRequest(url: callURL, newsBlurCredentials: credentials)
		try await transport.send(request: request)
	}

	/// GET URL with params
	@discardableResult
	func requestData<R: Decodable & Sendable>(callURL: URL, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		guard !isSuspended else { throw TransportError.suspended }

		let request = URLRequest(url: callURL, newsBlurCredentials: credentials)
		let response = try await transport.send(request: request, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
		return response
	}

	/// POST to URL with params, discard response
	func sendUpdates(callURL: URL, payload: NewsBlurDataConvertible) async throws {

		guard !isSuspended else { throw TransportError.suspended }

		var request = URLRequest(url: callURL, newsBlurCredentials: credentials)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: HTTPRequestHeader.contentType)
		request.httpBody = payload.asData

		try await transport.send(request: request, method: HTTPMethod.post)
	}

	/// POST to URL with params
	func sendUpdates<R: Decodable & Sendable>(callURL: URL, payload: NewsBlurDataConvertible, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		guard !isSuspended else { throw TransportError.suspended }

		guard let data = payload.asData else {
			throw NewsBlurError.invalidParameter
		}

		var request = URLRequest(url: callURL, newsBlurCredentials: credentials)
		request.setValue(MimeType.formURLEncoded, forHTTPHeaderField: HTTPRequestHeader.contentType)

		let response = try await transport.send(request: request, method: HTTPMethod.post, data: data, resultType: resultType, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
		return response
	}
}
