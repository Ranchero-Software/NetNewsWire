//
//  ReaderAPICustomHTTPHeaderTests.swift
//  AccountTests
//
//  Created by NetNewsWire.
//

import XCTest
@testable import Account

final class ReaderAPICustomHTTPHeaderTests: XCTestCase {

	func testCreatesAnyNumberOfValidHeaders() throws {
		let headers = try (0..<25).map { index in
			try XCTUnwrap(ReaderAPICustomHTTPHeader(name: "X-Test-Header-\(index)", value: "value-\(index)"))
		}

		XCTAssertEqual(headers.count, 25)
		XCTAssertEqual(headers.first?.name, "X-Test-Header-0")
		XCTAssertEqual(headers.last?.value, "value-24")
	}

	func testHeadersRoundTripThroughJSONForKeychainStorage() throws {
		let headers = try (0..<25).map { index in
			try XCTUnwrap(ReaderAPICustomHTTPHeader(name: "X-Test-Header-\(index)", value: "value-\(index)"))
		}

		let data = try JSONEncoder().encode(headers)
		let decoded = try JSONDecoder().decode([ReaderAPICustomHTTPHeader].self, from: data)

		XCTAssertEqual(decoded, headers)
	}

	func testHeaderValidationRejectsPartialOrUnsafeInput() {
		XCTAssertNil(ReaderAPICustomHTTPHeader(name: "", value: "value"))
		XCTAssertNil(ReaderAPICustomHTTPHeader(name: "Header Name", value: "value"))
		XCTAssertNil(ReaderAPICustomHTTPHeader(name: "X-Test", value: ""))
		XCTAssertNil(ReaderAPICustomHTTPHeader(name: "X-Test", value: "value\nInjected: nope"))
	}

	func testHeaderValidationTrimsInput() throws {
		let header = try XCTUnwrap(ReaderAPICustomHTTPHeader(name: "  X-Test  ", value: "  value  "))

		XCTAssertEqual(header.name, "X-Test")
		XCTAssertEqual(header.value, "value")
	}

	@MainActor func testClientLoginAuthTokenAllowsEqualsInTokenValue() throws {
		let rawData = """
		SID=session
		LSID=session2
		Auth=token-with-padding==
		"""

		XCTAssertEqual(ReaderAPICaller.clientLoginAuthToken(in: rawData), "token-with-padding==")
	}

}
