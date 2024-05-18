//
//  ArrayExtensionsTests.swift
//  
//
//  Created by Brent Simmons on 5/18/24.
//

import XCTest
import FoundationExtras

final class ArrayExtensionsTests: XCTestCase {

	// MARK: - Test chunked(into:)

	func testChunkedInto_Empty() {

		let testArray = [Int]()
		let resultArray = testArray.chunked(into: 50)
		XCTAssert(resultArray.isEmpty)
	}

	func testChunkedInto_LessThanOneChunk() {

		let testArray = [1, 2, 3, 4, 5, 6];
		let resultArray = testArray.chunked(into: 7)
		XCTAssert(resultArray.count == 1)

		let singleElement = resultArray[0]
		XCTAssertEqual(singleElement, testArray)
	}
}
