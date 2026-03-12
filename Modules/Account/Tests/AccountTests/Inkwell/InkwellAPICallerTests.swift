//
//  InkwellAPICallerTests.swift
//  AccountTests
//
//  Created by Manton Reece on 3/11/26.
//

import XCTest
import RSWeb
import Secrets
@testable import Account

final class InkwellAPICallerTests: XCTestCase {
	func testBearerCredentialsUseBearerAuthorizationHeader() {
		let credentials = Credentials(type: .bearerAccessToken, username: "manton", secret: "ABCDEF")
		let request = URLRequest(url: URL(string: "https://micro.blog/feeds/v2/subscriptions.json")!, credentials: credentials)

		XCTAssertEqual("Bearer ABCDEF", request.value(forHTTPHeaderField: HTTPRequestHeader.authorization))
	}

	@MainActor func testVerifyAccessTokenUsesFormEncodedBody() async throws {
		let transport = RecordingTransport()
		let caller = InkwellAPICaller(transport: transport)

		let response = try await caller.verifyAccessToken("ABCDEF")

		XCTAssertEqual("POST", transport.lastMethod)
		XCTAssertEqual(MimeType.formURLEncoded, transport.lastRequest?.value(forHTTPHeaderField: HTTPRequestHeader.contentType))
		let body = String(data: transport.lastRequestBody ?? Data(), encoding: .utf8)
		XCTAssertEqual("token=ABCDEF", body)
		XCTAssertEqual("NEW-TOKEN", response.token)
		XCTAssertTrue(response.hasInkwell)
		XCTAssertEqual("manton", response.username)
	}

	@MainActor func testRetrieveSubscriptionsRefreshesBearerTokenAfterUnauthorized() async throws {
		let transport = RefreshingTransport()
		let caller = InkwellAPICaller(transport: transport)
		caller.credentials = Credentials(type: .bearerAccessToken, username: "manton", secret: "OLD-TOKEN")

		let subscriptions = try await caller.retrieveSubscriptions()

		XCTAssertEqual(1, subscriptions?.count)
		XCTAssertEqual(1, transport.verifyRequestCount)
		XCTAssertEqual(["Bearer OLD-TOKEN", "Bearer NEW-TOKEN"], transport.subscriptionAuthorizationHeaders)
		XCTAssertEqual("NEW-TOKEN", caller.credentials?.secret)
	}
}

private final class RecordingTransport: Transport, @unchecked Sendable {
	nonisolated(unsafe) var lastRequest: URLRequest?
	nonisolated(unsafe) var lastRequestBody: Data?
	nonisolated(unsafe) var lastMethod: String?

	func cancelAll() {
	}

	func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?) {
		throw TransportError.noData
	}

	func send(request: URLRequest, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		completion(.failure(TransportError.noData))
	}

	func send(request: URLRequest, method: String) async throws {
		throw TransportError.noData
	}

	func send(request: URLRequest, method: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		completion(.failure(TransportError.noData))
	}

	func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?) {
		lastRequest = request
		lastRequestBody = payload
		lastMethod = method

		let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
		let data = """
		{"token":"NEW-TOKEN","has_inkwell":true,"name":"Manton Reece","username":"manton","avatar":"https://example.com/avatar.png"}
		""".data(using: .utf8)
		return (response, data)
	}

	func send(request: URLRequest, method: String, payload: Data, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		Task {
			do {
				let result = try await send(request: request, method: method, payload: payload)
				completion(.success(result))
			} catch {
				completion(.failure(error))
			}
		}
	}
}

private final class RefreshingTransport: Transport, @unchecked Sendable {
	nonisolated(unsafe) var subscriptionAuthorizationHeaders = [String]()
	nonisolated(unsafe) var verifyRequestCount = 0

	func cancelAll() {
	}

	func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?) {
		let url = request.url!.absoluteString

		if url.contains("/feeds/v2/subscriptions.json") {
			if let header = request.value(forHTTPHeaderField: HTTPRequestHeader.authorization) {
				subscriptionAuthorizationHeaders.append(header)
			}

			if subscriptionAuthorizationHeaders.count == 1 {
				throw TransportError.httpError(status: HTTPResponseCode.unauthorized)
			}

			let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
			let data = """
			[{"id":10,"feed_id":1296379,"title":"Daring Fireball","feed_url":"https://daringfireball.net/feeds/json","site_url":"https://daringfireball.net/"}]
			""".data(using: .utf8)
			return (response, data)
		}

		throw TransportError.noData
	}

	func send(request: URLRequest, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		Task {
			do {
				let result = try await send(request: request)
				completion(.success(result))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func send(request: URLRequest, method: String) async throws {
		throw TransportError.noData
	}

	func send(request: URLRequest, method: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		completion(.failure(TransportError.noData))
	}

	func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?) {
		let url = request.url!.absoluteString

		if url == "https://micro.blog/account/verify" {
			verifyRequestCount += 1
			let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
			let data = """
			{"token":"NEW-TOKEN","has_inkwell":true,"name":"Manton Reece","username":"manton","avatar":"https://example.com/avatar.png"}
			""".data(using: .utf8)
			return (response, data)
		}

		throw TransportError.noData
	}

	func send(request: URLRequest, method: String, payload: Data, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		Task {
			do {
				let result = try await send(request: request, method: method, payload: payload)
				completion(.success(result))
			} catch {
				completion(.failure(error))
			}
		}
	}
}
