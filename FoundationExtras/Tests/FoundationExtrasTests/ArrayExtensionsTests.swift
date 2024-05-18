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

	func testChunkedInto_MoreThanOneChunk() {

		let testArray = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
		let resultArray = testArray.chunked(into: 4)
		XCTAssert(resultArray.count == 4)

		var i = 0
		for elementArray in resultArray {
			let start = (4 * i)

			let expectedElementArray = {
				if i == 3 {
					return [13]
				} else {
					return [start + 1, start + 2, start + 3, start + 4]
				}
			}()

			XCTAssertEqual(elementArray, expectedElementArray)
			i = i + 1
		}
	}

	// MARK: - Test maxY

	func testMaxY_Empty() {

		let y = [CGRect]().maxY()
		XCTAssertEqual(y, 0.0)
	}

	func testMaxY() {

		let expectedMaxYRect = CGRect(x: 33.0, y: 9845.0, width: 32, height: 100.57)
		let testArray = [
			CGRect(x: 0.0, y: 64.0, width: 32, height: 1024),
			CGRect(x: 1000.0, y: 9845.0, width: 32, height: 32),
			CGRect(x: -3.0, y: -633.0, width: 32, height: 6578),
			expectedMaxYRect,
			CGRect(x: 4, y: 9845.0, width: 32, height: -644),
			CGRect(x: 1239, y: 9845.0, width: 32, height: 43)
		]

		let result = testArray.maxY()
		XCTAssertEqual(result, expectedMaxYRect.maxY)
	}
}
