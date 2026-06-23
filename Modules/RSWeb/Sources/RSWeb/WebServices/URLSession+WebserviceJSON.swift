//
//  URLSession+WebserviceJSON.swift
//  RSWeb
//
//  Created by Maurice Parker on 5/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

nonisolated extension URLSession {

	/// Send an HTTP GET and return JSON object(s).
	public func send<R: Decodable & Sendable>(request: URLRequest, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		let (response, data) = try await send(request: request)
		guard !data.isEmpty else {
			return (response, nil)
		}
		let decoded = try await Self.decode(R.self, from: data, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
		return (response, decoded)
	}

	/// Send the specified HTTP method with a JSON payload.
	public func send<P: Encodable & Sendable>(request: URLRequest, method: String, payload: P) async throws {

		var postRequest = request
		postRequest.addValue("application/json; charset=utf-8", forHTTPHeaderField: HTTPRequestHeader.contentType)

		let data = try await Self.encode(payload)
		_ = try await send(request: postRequest, method: method, payload: data)
	}

	/// Send the specified HTTP method with a raw payload and return JSON object(s).
	public func send<R: Decodable & Sendable>(request: URLRequest, method: String, data: Data, resultType: R.Type, dateDecoding: JSONDecoder.DateDecodingStrategy = .iso8601, keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> (HTTPURLResponse, R?) {

		let (response, responseData) = try await send(request: request, method: method, payload: data)
		guard !responseData.isEmpty else {
			return (response, nil)
		}
		let decoded = try await Self.decode(R.self, from: responseData, dateDecoding: dateDecoding, keyDecoding: keyDecoding)
		return (response, decoded)
	}

	@concurrent
	private static func encode<P: Encodable & Sendable>(_ payload: P) async throws -> Data {
		assert(!Thread.isMainThread, "JSON encoding should not happen on the main thread.")
		return try JSONEncoder().encode(payload)
	}

	@concurrent
	private static func decode<R: Decodable & Sendable>(_ type: R.Type, from data: Data, dateDecoding: JSONDecoder.DateDecodingStrategy, keyDecoding: JSONDecoder.KeyDecodingStrategy) async throws -> R {
		assert(!Thread.isMainThread, "JSON decoding should not happen on the main thread.")
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = dateDecoding
		decoder.keyDecodingStrategy = keyDecoding
		return try decoder.decode(R.self, from: data)
	}
}
