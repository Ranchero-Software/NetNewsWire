//
//  FeedlyTextSanitizationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Feedly

final class FeedlyTextSanitizationTests: XCTestCase {

	func testRTLSanitization() {
		
		let targetsAndExpectations: [(target: String?, expectation: String?)] = [
			(nil, nil),
			("", ""),
			(" ", " "),
			("text", "text"),
			("<div style=\"direction:rtl;text-align:right\">", "<div style=\"direction:rtl;text-align:right\">"),
			("</div>", "</div>"),
			("<div style=\"direction:rtl;text-align:right\">text", "<div style=\"direction:rtl;text-align:right\">text"),
			("text</div>", "text</div>"),
			("<div style=\"direction:rtl;text-align:right\"></div>", ""),
			("<DIV style=\"direction:rtl;text-align:right\"></div>", "<DIV style=\"direction:rtl;text-align:right\"></div>"),
			("<div style=\"direction:rtl;text-align:right\"></DIV>", "<div style=\"direction:rtl;text-align:right\"></DIV>"),
			("<div style=\"direction:rtl;text-align:right\">text</div>", "text"),
		]
		
		let sanitizer = FeedlyRTLTextSanitizer()
		
		for (target, expectation) in targetsAndExpectations {
			let calculated = sanitizer.sanitize(target)
			XCTAssertEqual(expectation, calculated)
		}
	}
}
