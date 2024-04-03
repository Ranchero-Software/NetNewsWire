//
//  RSDateParserTests.swift
//  
//
//  Created by Maurice Parker on 4/1/21.
//

import Foundation
import XCTest
import Parser

class RSDateParserTests: XCTestCase {
	
	static func dateWithValues(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
		var dateComponents = DateComponents()
		dateComponents.calendar = Calendar.current
		dateComponents.timeZone = TimeZone(secondsFromGMT: 0)
		
		dateComponents.year = year
		dateComponents.month = month
		dateComponents.day = day
		dateComponents.hour = hour
		dateComponents.minute = minute
		dateComponents.second = second
		
		return dateComponents.date!
	}
	
	func testDateWithString() {
		var expectedDateResult = Self.dateWithValues(2010, 5, 28, 21, 3, 38)
		
		var d = RSDateWithString("Fri, 28 May 2010 21:03:38 +0000")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("Fri, 28 May 2010 21:03:38 +00:00")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("Fri, 28 May 2010 21:03:38 -00:00")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("Fri, 28 May 2010 21:03:38 -0000")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("Fri, 28 May 2010 21:03:38 GMT")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("2010-05-28T21:03:38+00:00")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("2010-05-28T21:03:38+0000")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("2010-05-28T21:03:38-0000")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("2010-05-28T21:03:38-00:00")
		XCTAssertEqual(d, expectedDateResult)

		d = RSDateWithString("2010-05-28T21:03:38Z")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 7, 13, 17, 6, 40)
		d = RSDateWithString("2010-07-13T17:06:40+00:00")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 4, 30, 12, 0, 0)
		d = RSDateWithString("30 Apr 2010 5:00 PDT")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 5, 21, 21, 22, 53)
		d = RSDateWithString("21 May 2010 21:22:53 GMT")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 6, 9, 5, 0, 0)
		d = RSDateWithString("Wed, 09 Jun 2010 00:00 EST")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 6, 23, 3, 43, 50)
		d = RSDateWithString("Wed, 23 Jun 2010 03:43:50 Z")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 6, 22, 3, 57, 49)
		d = RSDateWithString("2010-06-22T03:57:49+00:00")
		XCTAssertEqual(d, expectedDateResult)

		expectedDateResult = Self.dateWithValues(2010, 11, 17, 13, 40, 07)
		d = RSDateWithString("2010-11-17T08:40:07-05:00")
		XCTAssertEqual(d, expectedDateResult)
	}

	func testAtomDateWithMissingTCharacter() {
		let expectedDateResult = Self.dateWithValues(2010, 11, 17, 13, 40, 07)
		let d = RSDateWithString("2010-11-17 08:40:07-05:00")
		XCTAssertEqual(d, expectedDateResult)
	}
	
	func testFeedbinDate() {
		let expectedDateResult = Self.dateWithValues(2019, 9, 27, 21, 01, 48)
		let d = RSDateWithString("2019-09-27T21:01:48.000000Z")
		XCTAssertEqual(d, expectedDateResult)
	}

//	func testHighMillisecondDate() {
//		let expectedDateResult = Self.dateWithValues(2021, 03, 29, 10, 46, 56)
//		let d = RSDateWithString("2021-03-29T10:46:56.516941+00:00")
//		XCTAssertEqual(d, expectedDateResult)
//	}
}
