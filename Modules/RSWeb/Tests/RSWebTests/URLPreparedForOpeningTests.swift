//
//  URLPreparedForOpeningTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/1/26.
//

import Foundation
import Testing
import RSWeb

struct URLPreparedForOpeningTests {

	@Test func allowsWebAndMailSchemes() throws {
		#expect(try url("http://example.com/").preparedForOpeningInBrowser() != nil)
		#expect(try url("https://example.com/").preparedForOpeningInBrowser() != nil)
		#expect(try url("mailto:me@example.com").preparedForOpeningInBrowser() != nil)
	}

	@Test func blocksOtherSchemes() throws {
		#expect(try url("smb://server/share").preparedForOpeningInBrowser() == nil)
		#expect(try url("file:///etc/passwd").preparedForOpeningInBrowser() == nil)
		#expect(try url("ftp://example.com/x").preparedForOpeningInBrowser() == nil)
		#expect(try url("javascript:alert(1)").preparedForOpeningInBrowser() == nil)
		#expect(try url("data:text/html,x").preparedForOpeningInBrowser() == nil)
		#expect(try url("tel:+15555555555").preparedForOpeningInBrowser() == nil)
	}

	@Test func schemeMatchIsCaseInsensitive() throws {
		#expect(try url("HTTPS://example.com/").preparedForOpeningInBrowser() != nil)
		#expect(try url("MailTo:me@example.com").preparedForOpeningInBrowser() != nil)
	}

	@Test func allowedURLPassesThroughUnchanged() throws {
		let prepared = try #require(url("http://example.com/path?q=1").preparedForOpeningInBrowser())
		#expect(prepared.absoluteString == "http://example.com/path?q=1")
	}

	private func url(_ string: String) throws -> URL {
		try #require(URL(string: string))
	}
}
