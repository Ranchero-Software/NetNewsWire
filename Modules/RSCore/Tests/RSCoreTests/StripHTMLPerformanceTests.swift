//
//  StripHTMLPerformanceTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest

final class StripHTMLPerformanceTests: XCTestCase {

	func testStrippingHTMLPerformance() {
		let html = """
		<html><body>
		<p>This is a test article with <b>bold text</b> and <i>italic text</i>.</p>
		<script>console.log('test');</script>
		<style>body { margin: 0; }</style>
		<p>More content with <a href="http://example.com">links</a> and other tags.</p>
		<div>Nested <span>tags</span> are common in HTML.</div>
		</body></html>
		"""

		self.measure {
			for _ in 0..<1000 {
				_ = html.strippingHTML(maxCharacters: 300)
			}
		}
	}

	func testStrippingHTMLPerformanceRealWorld() throws {
		let testFiles = ["daringfireball", "apple", "inessential", "scripting"]
		var htmlFiles: [String] = []

		for testFile in testFiles {
			guard let url = Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources") else {
				XCTFail("Could not find \(testFile).html")
				return
			}
			let html = try String(contentsOf: url, encoding: .utf8)
			htmlFiles.append(html)
		}

		self.measure {
			for _ in 0..<100 {
				for html in htmlFiles {
					_ = html.strippingHTML(maxCharacters: 300)
				}
			}
		}
	}
}
