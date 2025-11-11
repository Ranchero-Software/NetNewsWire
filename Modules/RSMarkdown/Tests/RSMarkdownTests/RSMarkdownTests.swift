//
//  RSMarkdownTests.swift
//  RSMarkdown
//
//  Created by Brent Simmons on 10/7/25.
//  Copyright © 2025 Brent Simmons. All rights reserved.
//

import XCTest
import Foundation
@testable import RSMarkdown

// We’re using Apple’s swift-markdown package for Markdown parsing and HTML generation:
// https://github.com/swiftlang/swift-markdown
// Apple’s module has its own testing. These tests here are just for sanity checking,
// to make sure nothing has gone wrong.

final class RSMarkdownTests: XCTestCase {

	// MARK: - Helper Functions

	private func loadMarkdownFile(named name: String) throws -> String {
		let bundle = Bundle.module
		let url = bundle.url(forResource: name, withExtension: "markdown")!
		return try String(contentsOf: url, encoding: .utf8)
	}

	// MARK: - Simple tests

	func testBoldFormatting() throws {
		let markdown = "This is **bold** text."
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<strong>bold</strong>"))
		XCTAssertTrue(html.contains("<p>This is <strong>bold</strong> text.</p>"))
	}

	func testHeadingFormatting() throws {
		let markdown = "# Main Heading\n## Sub Heading"
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<h1>Main Heading</h1>"))
		XCTAssertTrue(html.contains("<h2>Sub Heading</h2>"))
	}

	func testLinkFormatting() throws {
		let markdown = "Visit [Apple](https://apple.com) for more info."
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<a href=\"https://apple.com\">Apple</a>"))
		XCTAssertTrue(html.contains("<p>Visit <a href=\"https://apple.com\">Apple</a> for more info.</p>"))
	}

	func testMarkdownParsingPerformance() throws {
		let markdown = try loadMarkdownFile(named: "why-netnewswire-is-not-web-app")

		measure {
			let html = RSMarkdown.markdownToHTML(markdown)

			// Verify the output is valid HTML (inside measure block to ensure correctness)
			XCTAssertFalse(html.isEmpty)
			XCTAssertTrue(html.contains("<"))
			XCTAssertTrue(html.contains(">"))
		}
	}

	// MARK: - Essential Markdown Features

	func testInlineCode() throws {
		let markdown = "This is `inline code` in text."
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<code>inline code</code>"))
	}

	func testCodeBlocks() throws {
		let markdown = """
		```swift
		let hello = "world"
		```
		"""
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<pre><code"))
		XCTAssertTrue(html.contains("let hello = \"world\""))
	}

	func testUnorderedList() throws {
		let markdown = """
		- Item 1
		- Item 2
		- Item 3
		"""
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<ul>"))
		XCTAssertTrue(html.contains("<li><p>Item 1</p>"))
		XCTAssertTrue(html.contains("<li><p>Item 2</p>"))
		XCTAssertTrue(html.contains("</ul>"))
	}

	func testOrderedList() throws {
		let markdown = """
		1. First item
		2. Second item
		3. Third item
		"""
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<ol>"))
		XCTAssertTrue(html.contains("<li><p>First item</p>"))
		XCTAssertTrue(html.contains("<li><p>Second item</p>"))
		XCTAssertTrue(html.contains("</ol>"))
	}

	func testNestedFormatting() throws {
		let markdown = "Visit [**Apple**](https://apple.com) for *really* good stuff."
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<a href=\"https://apple.com\"><strong>Apple</strong></a>"))
		XCTAssertTrue(html.contains("<em>really</em>"))
	}

	func testLineBreaksAndParagraphs() throws {
		let markdown = """
		First paragraph.

		Second paragraph with  
		line break.
		"""
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<p>First paragraph.</p>"))
		XCTAssertTrue(html.contains("<p>Second paragraph"))
	}

	func testSpecialCharactersAndEscaping() throws {
		let markdown = "Use < and > symbols, plus 5 < 10 comparison."
		let html = RSMarkdown.markdownToHTML(markdown)

		// Note: swift-markdown currently doesn't escape < and > in text content
		// This test verifies the current behavior, though ideally they would be escaped
		XCTAssertTrue(html.contains("<p>Use < and > symbols"))
		XCTAssertTrue(html.contains("5 < 10 comparison"))
		XCTAssertTrue(html.contains("</p>"))
	}

	// MARK: - Edge Cases

	func testEmptyString() throws {
		let markdown = ""
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssert(html.isEmpty || html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
	}

	func testPlainText() throws {
		let markdown = "This is just plain text with no markdown formatting."
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<p>This is just plain text with no markdown formatting.</p>"))
		XCTAssertTrue(!html.contains("<strong>"))
		XCTAssertTrue(!html.contains("<em>"))
	}

	func testMalformedMarkdown() throws {
		let markdown = "This has **unclosed bold and [incomplete link"
		let html = RSMarkdown.markdownToHTML(markdown)

		// Should not crash and should produce some reasonable output
		XCTAssertFalse(html.isEmpty)
		XCTAssertTrue(html.contains("unclosed bold"))
	}

	func testVeryLargeContent() throws {
		// Create a large markdown string
		let baseMarkdown = "# Large Header\n\nThis is a paragraph with **bold** and *italic* text. "
		let largeMarkdown = String(repeating: baseMarkdown, count: 1000)

		let html = RSMarkdown.markdownToHTML(largeMarkdown)

		XCTAssertFalse(html.isEmpty)
		XCTAssertTrue(html.contains("<h1>Large Header</h1>"))
		XCTAssertTrue(html.contains("<strong>bold</strong>"))
	}

	// MARK: - Real-world Scenarios

	func testMixedMarkdownAndHTML() throws {
		let markdown = "This is **markdown** with <em>some HTML</em> mixed in."
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<strong>markdown</strong>"))
		XCTAssertTrue(html.contains("<em>some HTML</em>"))
	}

	func testUnicodeAndEmoji() throws {
		let markdown = "Unicode: café, naïve, résumé. Emoji: 🚀 🎉 ✨"
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("café"))
		XCTAssertTrue(html.contains("🚀"))
		XCTAssertTrue(html.contains("🎉"))
	}

	func testComplexNestedStructures() throws {
		let markdown = """
		# Main Header

		## Sub Header

		Here's a list with **bold** items:

		1. First item with [a link](https://example.com)
		2. Second item with `inline code`
		3. Third item with *emphasis*

		And a code block:

		```
		function test() {
			return "hello";
		}
		```
		"""
		let html = RSMarkdown.markdownToHTML(markdown)

		XCTAssertTrue(html.contains("<h1>Main Header</h1>"))
		XCTAssertTrue(html.contains("<h2>Sub Header</h2>"))
		XCTAssertTrue(html.contains("<ol>"))
		XCTAssertTrue(html.contains("<a href=\"https://example.com\">a link</a>"))
		XCTAssertTrue(html.contains("<code>inline code</code>"))
		XCTAssertTrue(html.contains("<pre><code>"))
	}

	// MARK: - Performance/Robustness

	func testRepeatedParsing() throws {
		let markdown = "# Test Header\n\nThis is a **test** with *emphasis* and [links](https://example.com)."

		// Parse the same content multiple times
		for _ in 0..<100 {
			let html = RSMarkdown.markdownToHTML(markdown)

			XCTAssertTrue(html.contains("<h1>Test Header</h1>"))
			XCTAssertTrue(html.contains("<strong>test</strong>"))
		}
	}

	func testMemoryUsageWithLargeFile() throws {
		// Create a very large markdown document
		let section = """
		## Section Header

		This is a paragraph with **bold**, *italic*, and `code` formatting.

		- List item 1
		- List item 2 with [link](https://example.com)

		```swift
		let code = "example"
		print(code)
		```

		"""

		let largeMarkdown = String(repeating: section, count: 500)

		let startTime = CFAbsoluteTimeGetCurrent()
		let html = RSMarkdown.markdownToHTML(largeMarkdown)
		let endTime = CFAbsoluteTimeGetCurrent()

		// Should complete within reasonable time even for large content
		XCTAssertLessThan(endTime - startTime, 1.0)
		XCTAssertFalse(html.isEmpty)
		XCTAssertTrue(html.contains("<h2>Section Header</h2>"))
	}
}
