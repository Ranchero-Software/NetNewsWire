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

#if os(macOS)

	func testAllBrowsers() {
		let browsers = MacWebBrowser.sortedBrowsers()

		XCTAssertNotNil(browsers);
	}

#endif
}
