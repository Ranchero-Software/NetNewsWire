//
//  URL+RSCoreTests.swift
//  RSCore
//
//  Created by Brent Simmons on 7/27/26.
//

import Foundation
import Testing
import RSCore

struct URLRSCoreTests {

	// An already-encoded mailto URL must pass through unchanged — re-encoding
	// turned %20 into %2520, showing literal "%20" in Mail.
	// <https://github.com/Ranchero-Software/NetNewsWire/issues/3719>
	// <https://github.com/Ranchero-Software/NetNewsWire/issues/4380>
	@Test func percentEncodedEmailAddressDoesNotDoubleEncode() throws {
		let url = try #require(URL(string: "mailto:test@example.com?subject=Hello%20World"))
		#expect(url.percentEncodedEmailAddress?.absoluteString == "mailto:test@example.com?subject=Hello%20World")
	}

	@Test func percentEncodedEmailAddressPreservesMultipleEscapes() throws {
		let url = try #require(URL(string: "mailto:test@example.com?subject=One%20Two%20Three&body=Hi%2C%20there"))
		#expect(url.percentEncodedEmailAddress?.absoluteString == "mailto:test@example.com?subject=One%20Two%20Three&body=Hi%2C%20there")
	}

	@Test func percentEncodedEmailAddressIsIdempotent() throws {
		let url = try #require(URL(string: "mailto:test@example.com?subject=Hello%20World"))
		let once = url.percentEncodedEmailAddress
		let twice = once?.percentEncodedEmailAddress
		#expect(once == twice)
	}

	@Test func percentEncodedEmailAddressRequiresMailto() throws {
		let url = try #require(URL(string: "https://example.com/"))
		#expect(url.percentEncodedEmailAddress == nil)
	}

	@Test func percentEncodedEmailAddressPlainAddress() throws {
		let url = try #require(URL(string: "mailto:test@example.com"))
		#expect(url.percentEncodedEmailAddress?.absoluteString == "mailto:test@example.com")
	}
}
