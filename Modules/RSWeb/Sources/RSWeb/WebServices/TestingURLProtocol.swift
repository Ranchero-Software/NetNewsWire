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

	/// What a registered response answers: a URL substring, and optionally one HTTP method.
	private struct ResponseKey: Hashable {
		let urlSubstring: String
		let httpMethod: String?
	}

	/// A request the protocol answered.
	private struct AnsweredRequest: Sendable {
		let urlString: String
		let httpMethod: String?
	}

	/// What one test registered, and what it has been asked for since.
	private struct TestState: Sendable {
		var responses = [ResponseKey: Response]()
		var answeredRequests = [AnsweredRequest]()
	}

	/// Maps a test ID to its state. Requests from a session built outside a
	/// `currentTestID` scope use `sharedTestID`.
	private static let testStates = OSAllocatedUnfairLock<[String: TestState]>(initialState: [:])

	private static let sharedTestID = "shared"

	/// Register the response to return for requests whose URL contains `urlSubstring`.
	/// Pass `httpMethod` — `HTTPMethod.post` and friends — to answer only that method.
	/// A registration without one answers any method no method-specific registration claims.
	public static func setResponse(_ response: Response, forURLContaining urlSubstring: String, httpMethod: String? = nil) {
		let testID = currentTestID ?? sharedTestID
		let key = ResponseKey(urlSubstring: urlSubstring, httpMethod: httpMethod)
		testStates.withLock { $0[testID, default: TestState()].responses[key] = response }
	}

	/// How many requests this test has been asked for whose URL contains `urlSubstring`.
	/// Pass `httpMethod` to count only that method. Counts requests whether or not a
	/// response was registered for them.
	public static func requestCount(forURLContaining urlSubstring: String, httpMethod: String? = nil) -> Int {
		let testID = currentTestID ?? sharedTestID
		return testStates.withLock { testStates in
			let answeredRequests = testStates[testID]?.answeredRequests ?? []
			return answeredRequests.count { answeredRequest in
				guard answeredRequest.urlString.contains(urlSubstring) else {
					return false
				}
				guard let httpMethod else {
					return true
				}
				return answeredRequest.httpMethod == httpMethod
			}
		}
	}

	/// Clears everything recorded for the current test. Call between tests.
	public static func reset() {
		endTest(withID: currentTestID ?? sharedTestID)
	}

	/// Discards one test's registrations and request history, for a scope that is ending.
	public static func endTest(withID testID: String) {
		testStates.withLock { $0[testID] = nil }
	}

	private static func recordRequest(_ request: URLRequest) {
		guard let urlString = request.url?.absoluteString else {
			return
		}

		let testID = request.value(forHTTPHeaderField: testIDHeaderField) ?? sharedTestID
		let answeredRequest = AnsweredRequest(urlString: urlString, httpMethod: request.httpMethod)
		testStates.withLock { $0[testID, default: TestState()].answeredRequests.append(answeredRequest) }
	}

	private static func response(for request: URLRequest) -> Response? {
		guard let urlString = request.url?.absoluteString else {
			return nil
		}

		let testID = request.value(forHTTPHeaderField: testIDHeaderField) ?? sharedTestID
		return testStates.withLock { testStates in
			guard let responsesForTest = testStates[testID]?.responses else {
				return nil
			}

			func response(forHTTPMethod httpMethod: String?) -> Response? {
				responsesForTest.first { key, _ in
					key.httpMethod == httpMethod && urlString.contains(key.urlSubstring)
				}?.value
			}

			// A registration for this request's method wins over one that answers any method.
			return response(forHTTPMethod: request.httpMethod) ?? response(forHTTPMethod: nil)
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

		Self.recordRequest(request)

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
