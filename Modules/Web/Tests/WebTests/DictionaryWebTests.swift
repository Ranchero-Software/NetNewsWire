//
//  DictionaryWebTests.swift
//  
//
//  Created by Brent Simmons on 5/20/24.
//

import XCTest
import Web

final class DictionaryWebTests: XCTestCase {

	func testURLQueryString_oneItemNoEscaping() {

		let d = ["parameterName" : "value"]
		let queryString = d.urlQueryString
		let expectedQueryString = "parameterName=value"
		XCTAssertEqual(queryString, expectedQueryString)
	}
}
