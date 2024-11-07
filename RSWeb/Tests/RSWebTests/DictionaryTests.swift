//
//  DictionaryTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import XCTest

class DictionaryTests: XCTestCase {

	func testSimpleQueryString() {

		let d = ["foo": "bar", "param1": "This is a value."]
		let s = d.urlQueryString

		XCTAssertTrue(s == "foo=bar&param1=This%20is%20a%20value." || s == "param1=This%20is%20a%20value.&foo=bar")
	}

	func testQueryStringWithAmpersand() {

		let d = ["fo&o": "bar", "param1": "This is a&value."]
		let s = d.urlQueryString

		XCTAssertTrue(s == "fo%26o=bar&param1=This%20is%20a%26value." || s == "param1=This%20is%20a%26value.&fo%26o=bar")
	}

	func testQueryStringWithAccentedCharacters() {

		let d = ["fée": "bør"]
		let s = d.urlQueryString

		XCTAssertTrue(s == "f%C3%A9e=b%C3%B8r")
	}

	func testQueryStringWithEmoji() {

		let d = ["🌴e": "bar🎩🌴"]
		let s = d.urlQueryString

		XCTAssertTrue(s == "%F0%9F%8C%B4e=bar%F0%9F%8E%A9%F0%9F%8C%B4")
	}

}
