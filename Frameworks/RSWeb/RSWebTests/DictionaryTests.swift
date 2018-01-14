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
		let s = d.urlQueryString()

		XCTAssertTrue(s == "foo=bar&param1=This+is+a+value." || s == "param1=This+is+a+value.&foo=bar")
	}

	func testQueryStringWithAmpersand() {

		let d = ["fo&o": "bar", "param1": "This is a&value."]
		let s = d.urlQueryString()

		XCTAssertTrue(s == "fo%38o=bar&param1=This+is+a%38value." || s == "param1=This+is+a%38value.&fo%38o=bar")
	}

	func testQueryStringWithAccentedCharacters() {

		let d = ["fée": "bør"]
		let s = d.urlQueryString()

		XCTAssertTrue(s == "f%C3%A9e=b%C3%B8r")
	}

	func testQueryStringWithEmoji() {

		let d = ["🌴e": "bar🎩🌴"]
		let s = d.urlQueryString()

		XCTAssertTrue(s == "%F0%9F%8C%B4e=bar%F0%9F%8E%A9%F0%9F%8C%B4")
	}

}
