//
//  TestingURLProtocol.swift
//  RSWeb
//
//  Created by Brent Simmons on 6/16/26.
//

import Foundation
import os

public final class TestingURLProtocol: URLProtocol {

	/// A canned response for a request whose URL contains a given substring.
	public struct Response: Sendable {
		public var statusCode: Int
		public var data: Data?

		public init(statusCode: Int = 200, data: Data? = nil) {
			self.statusCode = statusCode
			self.data = data
		}
	}

	/// Identifies the running test. A session built by `URLSession.makeWebserviceSession()`
	/// inside a scope where this is bound carries it, so concurrent tests registering the
	/// same URL substring don't see each other's responses.
	@TaskLocal public static var currentTestID: String?

	/// Carries `currentTestID` from the session's configuration to `startLoading`.
	public static let testIDHeaderField = "X-NetNewsWire-Testing-ID"

	/// Maps a test ID to that test's URL-substring-to-response table. Requests from a session
	/// built outside a `currentTestID` scope use `sharedTestID`.
	private static let responses = OSAllocatedUnfairLock<[String: [String: Response]]>(initialState: [:])

	private static let sharedTestID = "shared"

	/// Register the response to return for requests whose URL contains `urlSubstring`.
	public static func setResponse(_ response: Response, forURLContaining urlSubstring: String) {
		let testID = currentTestID ?? sharedTestID
		responses.withLock { $0[testID, default: [:]][urlSubstring] = response }
	}

	/// Clears the responses registered by the current test. Call between tests.
	public static func reset() {
		removeResponses(forTestID: currentTestID ?? sharedTestID)
	}

	/// Discards one test's responses, for a scope that is ending.
	public static func removeResponses(forTestID testID: String) {
		responses.withLock { $0[testID] = nil }
	}

	private static func response(for request: URLRequest) -> Response? {
		guard let urlString = request.url?.absoluteString else {
			return nil
		}

		let testID = request.value(forHTTPHeaderField: testIDHeaderField) ?? sharedTestID
		return responses.withLock { responses in
			responses[testID]?.first { urlString.contains($0.key) }?.value
		}
	}

	public override static func canInit(with request: URLRequest) -> Bool {
		true
	}

	public override static func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}

	public override func startLoading() {

		guard let url = request.url else {
			client?.urlProtocol(self, didFailWithError: URLError(.badURL))
			return
		}

		let match = Self.response(for: request)

		let httpResponse = HTTPURLResponse(url: url, statusCode: match?.statusCode ?? 200, httpVersion: "HTTP/1.1", headerFields: nil)!
		client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)

		if let data = match?.data {
			client?.urlProtocol(self, didLoad: data)
		}

		client?.urlProtocolDidFinishLoading(self)
	}

	public override func stopLoading() {
	}
}
