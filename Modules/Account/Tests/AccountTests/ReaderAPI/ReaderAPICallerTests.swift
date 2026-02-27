//
//  ReaderAPICallerTests.swift
//  AccountTests
//

import Foundation
import os
import RSWeb
import XCTest

@testable import Account

@MainActor final class ReaderAPICallerTests: XCTestCase {

	func testAllForAccountFreshRSSUsesBaselineWindowInsteadOfLastFetch() async throws {
		let transport = ReaderAPISpyTransport()
		let caller = ReaderAPICaller(transport: transport, logger: Logger(subsystem: "AccountTests", category: "ReaderAPI"))

		let accountMetadata = AccountMetadata()
		accountMetadata.endpointURL = URL(string: "https://example.com")!
		let lastFetch = Date().addingTimeInterval(-60 * 60 * 24) // 1 day ago
		accountMetadata.lastArticleFetchStartTime = lastFetch

		caller.variant = .freshRSS
		caller.accountMetadata = accountMetadata

		_ = try await caller.retrieveItemIDs(type: .allForAccount)

		guard let callURL = transport.lastRequestedURL else {
			return XCTFail("Expected retrieveItemIDs to issue a request.")
		}
		guard let ot = otFromURL(callURL) else {
			return XCTFail("Expected an ot query parameter in request URL: \(callURL.absoluteString)")
		}

		let expectedBaseline = Calendar.current.date(byAdding: .month, value: -3, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
		XCTAssertLessThan(abs(ot - expectedBaseline), 120, "FreshRSS should use the rolling baseline window for ot.")

		XCTAssertGreaterThan(abs(ot - lastFetch.timeIntervalSince1970), 60 * 60 * 24 * 7, "FreshRSS should not use the recent last fetch timestamp for ot.")
	}

	func testAllForAccountGenericUsesLastFetchTimestamp() async throws {
		let transport = ReaderAPISpyTransport()
		let caller = ReaderAPICaller(transport: transport, logger: Logger(subsystem: "AccountTests", category: "ReaderAPI"))

		let accountMetadata = AccountMetadata()
		accountMetadata.endpointURL = URL(string: "https://example.com")!
		let lastFetch = Date().addingTimeInterval(-60 * 60 * 24)
		accountMetadata.lastArticleFetchStartTime = lastFetch

		caller.variant = .generic
		caller.accountMetadata = accountMetadata

		_ = try await caller.retrieveItemIDs(type: .allForAccount)

		guard let callURL = transport.lastRequestedURL else {
			return XCTFail("Expected retrieveItemIDs to issue a request.")
		}
		guard let ot = otFromURL(callURL) else {
			return XCTFail("Expected an ot query parameter in request URL: \(callURL.absoluteString)")
		}

		XCTAssertLessThan(abs(ot - lastFetch.timeIntervalSince1970), 5, "Generic Reader API should continue to use lastArticleFetchStartTime for ot.")
	}

	private func otFromURL(_ url: URL) -> TimeInterval? {
		guard
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			let otValue = components.queryItems?.first(where: { $0.name == "ot" })?.value,
			let ot = TimeInterval(otValue)
		else {
			return nil
		}
		return ot
	}
}

private final class ReaderAPISpyTransport: Transport, @unchecked Sendable {
	nonisolated(unsafe) private(set) var lastRequestedURL: URL?

	func cancelAll() { }

	@discardableResult
	func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?) {
		guard let url = request.url else {
			throw TransportError.noURL
		}
		lastRequestedURL = url
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
		let payload = Data(#"{"itemRefs":[{"id":"1"}]}"#.utf8)
		return (response, payload)
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
		fatalError("Unimplemented for test.")
	}

	func send(request: URLRequest, method: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		fatalError("Unimplemented for test.")
	}

	func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?) {
		fatalError("Unimplemented for test.")
	}

	func send(request: URLRequest, method: String, payload: Data, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		fatalError("Unimplemented for test.")
	}
}
