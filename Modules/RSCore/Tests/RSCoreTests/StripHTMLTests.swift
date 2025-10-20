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
		let legacyResult = html.legacyStrippingHTML()
		let result = html.strippingHTML()

		// Note: C implementation trims leading/trailing whitespace, legacy Swift doesn't

		// Both should strip tags and collapse whitespace
		XCTAssertFalse(legacyResult.contains("<"))
		XCTAssertFalse(result.contains("<"))
		XCTAssertTrue(legacyResult.contains("Hello"))
		XCTAssertTrue(legacyResult.contains("world"))
		XCTAssertTrue(result.contains("Hello"))
		XCTAssertTrue(result.contains("world"))
	}

	func testStrippingHTMLWithScript() {
		let html = "<p>Before</p><script>alert('test');</script><p>After</p>"
		let legacyResult = html.legacyStrippingHTML()
		let result = html.strippingHTML()

		// Note: C implementation trims leading/trailing whitespace, legacy Swift doesn't

		// Both should remove script content
		XCTAssertFalse(legacyResult.contains("alert"))
		XCTAssertFalse(result.contains("alert"))
		XCTAssertTrue(legacyResult.contains("Before"))
		XCTAssertTrue(legacyResult.contains("After"))
		XCTAssertTrue(result.contains("Before"))
		XCTAssertTrue(result.contains("After"))
	}

	func testStrippingHTMLWithStyle() {
		let html = "<p>Content</p><style>body { color: red; }</style><p>More</p>"
		let legacyResult = html.legacyStrippingHTML()
		let result = html.strippingHTML()

		// Note: C implementation trims leading/trailing whitespace, legacy Swift doesn't

		// Both should remove style content
		XCTAssertFalse(legacyResult.contains("color"))
		XCTAssertFalse(result.contains("color"))
		XCTAssertTrue(legacyResult.contains("Content"))
		XCTAssertTrue(legacyResult.contains("More"))
		XCTAssertTrue(result.contains("Content"))
		XCTAssertTrue(result.contains("More"))
	}

	func testStrippingHTMLWithMaxCharacters() {
		let html = "<p>This is a long piece of text that should be truncated at some point.</p>"
		let legacyResult = html.legacyStrippingHTML(maxCharacters: 20)
		let result = html.strippingHTML(maxCharacters: 20)

		// Note: C implementation trims leading/trailing whitespace, legacy Swift doesn't

		// Both should respect maxCharacters limit
		XCTAssertLessThanOrEqual(legacyResult.count, 20)
		XCTAssertLessThanOrEqual(result.count, 20)
	}

	func testStrippingHTMLWithUTF8() {
		let html = "<p>Hello 世界 🌍</p>"
		let legacyResult = html.legacyStrippingHTML()
		let result = html.strippingHTML()

		// Note: C implementation trims leading/trailing whitespace, legacy Swift doesn't

		// Both should handle UTF-8 correctly
		XCTAssertTrue(legacyResult.contains("世界"))
		XCTAssertTrue(legacyResult.contains("🌍"))
		XCTAssertTrue(result.contains("世界"))
		XCTAssertTrue(result.contains("🌍"))
	}

	func testStrippingHTMLWhitespaceCollapsing() {
		let html = "<p>Too     many\n\n\nspaces</p>"
		let legacyResult = html.legacyStrippingHTML()
		let result = html.strippingHTML()

		// Note: C implementation trims leading/trailing whitespace, legacy Swift doesn't

		// Both should collapse consecutive whitespace
		XCTAssertFalse(legacyResult.contains("  "))
		XCTAssertFalse(result.contains("  "))
	}

	func testStrippingHTMLPerformanceLegacySwift() {
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
				let _ = html.legacyStrippingHTML(maxCharacters: 300)
			}
		}
	}

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
			let legacyResult = html.legacyStrippingHTML(maxCharacters: 300)
			let result = html.strippingHTML(maxCharacters: 300)

			// Note: Results may differ slightly because the legacy Swift implementation's regex-based
			// script removal (<script>[\s\S]*?</script>) doesn't handle script tags with attributes
			// like <script type="text/javascript">, while the C implementation correctly removes them.
			// Both produce usable output for article previews.

			// Both should produce non-empty results
			XCTAssertFalse(legacyResult.isEmpty, "\(testFile): Legacy result should not be empty")
			XCTAssertFalse(result.isEmpty, "\(testFile): Result should not be empty")

			// Both should respect the maxCharacters limit
			XCTAssertLessThanOrEqual(legacyResult.count, 300, "\(testFile): Legacy result should respect maxCharacters")
			XCTAssertLessThanOrEqual(result.count, 300, "\(testFile): Result should respect maxCharacters")

			// Both should strip HTML tags
			XCTAssertFalse(legacyResult.contains("<"), "\(testFile): Legacy result should not contain HTML tags")
			XCTAssertFalse(result.contains("<"), "\(testFile): Result should not contain HTML tags")

			// C implementation should not contain script artifacts
			XCTAssertFalse(result.contains("//"), "\(testFile): Should fully remove script content")
		}
	}

	func testStrippingHTMLPerformanceRealWorldLegacySwift() throws {
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
					let _ = html.legacyStrippingHTML(maxCharacters: 300)
				}
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
