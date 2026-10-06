//
//  HTTPLinkPagingInfoTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/1/26.
//

import Foundation
import Testing
import RSWeb

struct HTTPLinkPagingInfoTests {

	@Test func parsesNextAndLast() throws {
		let value = "<https://api.feedbin.com/v2/entries.json?page=2>; rel=\"next\", <https://api.feedbin.com/v2/entries.json?page=5>; rel=\"last\""
		let info = try makeInfo(linkHeader: value)
		#expect(info.nextPage == "https://api.feedbin.com/v2/entries.json?page=2")
		#expect(info.lastPage == "https://api.feedbin.com/v2/entries.json?page=5")
	}

	@Test func malformedSegmentDoesNotCrash() throws {
		// A segment with no "; " separator used to trap on components[1].
		let info = try makeInfo(linkHeader: "<https://api.feedbin.com/v2/entries.json?page=2>")
		#expect(info.nextPage == nil)
		#expect(info.lastPage == nil)
	}

	@Test func mixedValidAndMalformedSegments() throws {
		let value = "<https://api.feedbin.com/v2/entries.json?page=2>; rel=\"next\", <https://api.feedbin.com/v2/entries.json?page=9>"
		let info = try makeInfo(linkHeader: value)
		#expect(info.nextPage == "https://api.feedbin.com/v2/entries.json?page=2")
		#expect(info.lastPage == nil)
	}

	@Test func noLinkHeader() throws {
		let info = try makeInfo(linkHeader: nil)
		#expect(info.nextPage == nil)
		#expect(info.lastPage == nil)
	}

	private func makeInfo(linkHeader: String?) throws -> HTTPLinkPagingInfo {
		let url = try #require(URL(string: "https://api.feedbin.com/v2/entries.json"))
		var headerFields: [String: String] = [:]
		if let linkHeader {
			headerFields[HTTPResponseHeader.link] = linkHeader
		}
		let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headerFields))
		return HTTPLinkPagingInfo(urlResponse: response)
	}
}
