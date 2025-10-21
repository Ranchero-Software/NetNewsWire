//
//  StripHTMLTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 2025-10-20.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import XCTest

// Legacy Swift implementation for comparison testing
private extension String {

	/// Removes an HTML tag and everything between its start and end tags.
	private func removingTagAndContents(_ tag: String) -> String {
		return self.replacingOccurrences(of: "<\(tag)>[\\s\\S]*?</\(tag)>", with: "", options: [.regularExpression, .caseInsensitive])
	}

	/// Legacy Swift-based HTML stripping implementation (kept for comparison testing).
	func legacyStrippingHTML(maxCharacters: Int? = nil) -> String {
		if !self.contains("<") {

			if let maxCharacters = maxCharacters, maxCharacters < count {
				let ix = self.index(self.startIndex, offsetBy: maxCharacters)
				return String(self[..<ix])
			}

			return self
		}

		var preflight = self

		// NOTE: If performance on repeated invocations becomes an issue here, the regexes can be cached.
		let options: String.CompareOptions = [.regularExpression, .caseInsensitive]
		preflight = preflight.replacingOccurrences(of: "</?(?:blockquote|p|div)>", with: " ", options: options)
		preflight = preflight.replacingOccurrences(of: "<p>|</?div>|<br(?: ?/)?>|</li>", with: "\n", options: options)
		preflight = preflight.removingTagAndContents("script")
		preflight = preflight.removingTagAndContents("style")

		let preflightCount = preflight.count
		let maxChars = maxCharacters ?? preflightCount

		var s = String()
		s.reserveCapacity(min(maxChars, preflightCount))
		var lastCharacterWasSpace = false
		var charactersAdded = 0
		var level = 0

		for char in preflight {
			if char == "<" {
				level += 1
			} else if char == ">" {
				level -= 1
			} else if level == 0 {

				if char == " " || char == "\r" || char == "\t" || char == "\n" {
					if lastCharacterWasSpace {
						continue
					}
					lastCharacterWasSpace = true
					s.append(" ")
				} else {
					lastCharacterWasSpace = false
					s.append(char)
				}

				charactersAdded += 1
				if charactersAdded >= maxChars {
					break
				}
			}
		}

		return s
	}
}

final class StripHTMLTests: XCTestCase {

	func testStrippingHTMLBasic() {
		let html = "<p>Hello <b>world</b>!</p>"
		let result = html.strippingHTML()
		XCTAssertEqual(result, "Hello world!")
	}

	func testStrippingHTMLWithScript() {
		let html = "<p>Before</p><script>alert('test');</script><p>After</p>"
		let result = html.strippingHTML()
		XCTAssertEqual(result, "Before After")
	}

	func testStrippingHTMLWithStyle() {
		let html = "<p>Content</p><style>body { color: red; }</style><p>More</p>"
		let result = html.strippingHTML()
		XCTAssertEqual(result, "Content More")
	}

	func testStrippingHTMLWithMaxCharacters() {
		let html = "<p>This is a long piece of text that should be truncated at some point.</p>"
		let result = html.strippingHTML(maxCharacters: 20)
		XCTAssertLessThanOrEqual(result.count, 20)
		XCTAssertEqual(result, "This is a long piece")
	}

	func testStrippingHTMLWithUTF8() {
		let html = "<p>Hello 世界 🌍</p>"
		let result = html.strippingHTML()
		XCTAssertEqual(result, "Hello 世界 🌍")
	}

	func testStrippingHTMLWhitespaceCollapsing() {
		let html = "<p>Too     many\n\n\nspaces</p>"
		let result = html.strippingHTML()
		XCTAssertFalse(result.contains("  "))
		XCTAssertEqual(result, "Too many spaces")
	}

	// Commented out because this doesn’t need to run every time.
	// Un-comment it when you want to compare legacy performance to C performance.
//	func testStrippingHTMLPerformanceLegacySwift() {
//		let html = """
//		<html><body>
//		<p>This is a test article with <b>bold text</b> and <i>italic text</i>.</p>
//		<script>console.log('test');</script>
//		<style>body { margin: 0; }</style>
//		<p>More content with <a href="http://example.com">links</a> and other tags.</p>
//		<div>Nested <span>tags</span> are common in HTML.</div>
//		</body></html>
//		"""
//
//		self.measure {
//			for _ in 0..<1000 {
//				let _ = html.legacyStrippingHTML(maxCharacters: 300)
//			}
//		}
//	}

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
				let _ = html.strippingHTML(maxCharacters: 300)
			}
		}
	}

	func testStrippingHTMLWithRealWorldHTML() throws {
		let testFiles = ["daringfireball", "apple", "inessential", "scripting"]

		for testFile in testFiles {
			guard let url = Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources") else {
				XCTFail("Could not find \(testFile).html")
				return
			}

			let html = try String(contentsOf: url, encoding: .utf8)

			// Test both implementations can process real-world HTML
			let result = html.strippingHTML(maxCharacters: 300)

			XCTAssertFalse(result.isEmpty, "\(testFile): Result should not be empty")
			XCTAssertLessThanOrEqual(result.count, 300, "\(testFile): Result should respect maxCharacters")
			XCTAssertFalse(result.contains("<"), "\(testFile): Result should not contain HTML tags")
			XCTAssertFalse(result.contains("//"), "\(testFile): Should fully remove script content")
		}
	}

	// Commented out because this doesn’t need to run every time.
	// Un-comment it when you want to compare legacy performance to C performance.
//	func testStrippingHTMLPerformanceRealWorldLegacySwift() throws {
//		let testFiles = ["daringfireball", "apple", "inessential", "scripting"]
//		var htmlFiles: [String] = []
//
//		for testFile in testFiles {
//			guard let url = Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources") else {
//				XCTFail("Could not find \(testFile).html")
//				return
//			}
//			let html = try String(contentsOf: url, encoding: .utf8)
//			htmlFiles.append(html)
//		}
//
//		self.measure {
//			for _ in 0..<100 {
//				for html in htmlFiles {
//					let _ = html.legacyStrippingHTML(maxCharacters: 300)
//				}
//			}
//		}
//	}

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
					let _ = html.strippingHTML(maxCharacters: 300)
				}
			}
		}
	}

	func testStrippingHTMLMatchesExpectedOutput() throws {
		let testFiles = ["apple", "daringfireball", "inessential", "scripting"]

		for testFile in testFiles {
			guard let htmlURL = Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources") else {
				XCTFail("Could not find \(testFile).html")
				return
			}

			guard let txtURL = Bundle.module.url(forResource: testFile, withExtension: "txt", subdirectory: "Resources") else {
				XCTFail("Could not find \(testFile).txt")
				return
			}

			let html = try String(contentsOf: htmlURL, encoding: .utf8)
			let expectedOutput = try String(contentsOf: txtURL, encoding: .utf8)

			// Test implementation produces expected output
			let result = html.strippingHTML()

			XCTAssertEqual(result, expectedOutput, "\(testFile): Implementation should match expected output")
		}
	}
}
