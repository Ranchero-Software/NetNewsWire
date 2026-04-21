//
//  StripHTMLTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 2025-10-20.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import XCTest

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

	func testStrippingHTMLWithRealWorldHTML() throws {
		let testFiles = ["daringfireball", "apple", "inessential", "scripting"]

		for testFile in testFiles {
			guard let url = Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources") else {
				XCTFail("Could not find \(testFile).html")
				return
			}

			let html = try String(contentsOf: url, encoding: .utf8)
			let result = html.strippingHTML(maxCharacters: 300)

			XCTAssertFalse(result.isEmpty, "\(testFile): Result should not be empty")
			XCTAssertLessThanOrEqual(result.count, 300, "\(testFile): Result should respect maxCharacters")
			XCTAssertFalse(result.contains("<"), "\(testFile): Result should not contain HTML tags")
			XCTAssertFalse(result.contains("//"), "\(testFile): Should fully remove script content")
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

	// Un-comment this to create the .txt files that contain the expected stripped-HTML results.
	//	func testRegenerateExpectedOutputFiles() throws {
	//		let testFiles = ["apple", "daringfireball", "inessential", "scripting"]
	//
	//		for testFile in testFiles {
	//			guard let htmlURL = Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources") else {
	//				XCTFail("Could not find \(testFile).html")
	//				return
	//			}
	//
	//			let html = try String(contentsOf: htmlURL, encoding: .utf8)
	//			let result = html.strippingHTML()
	//
	//			print("\n=== \(testFile) ===")
	//			print("Result length: \(result.count) characters")
	//			print("First 200 chars: \(String(result.prefix(200)))")
	//
	//			// Write to /tmp first, then user can copy to source
	//			let tmpPath = "/tmp/\(testFile).txt"
	//			try result.write(toFile: tmpPath, atomically: true, encoding: .utf8)
	//			print("Wrote to: \(tmpPath)")
	//		}
	//
	//		print("\n\nTo update the expected output files, run:")
	//		print("cp /tmp/apple.txt Tests/RSCoreTests/Resources/")
	//		print("cp /tmp/daringfireball.txt Tests/RSCoreTests/Resources/")
	//		print("cp /tmp/inessential.txt Tests/RSCoreTests/Resources/")
	//		print("cp /tmp/scripting.txt Tests/RSCoreTests/Resources/")
	//	}
}
