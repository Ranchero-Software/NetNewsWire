//
//  RSWebTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 12/22/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSWeb

final class RSWebTests: XCTestCase {

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

	func testAllBrowsers() {
		let browsers = MacWebBrowser.sortedBrowsers()

		XCTAssertNotNil(browsers)
	}

}
