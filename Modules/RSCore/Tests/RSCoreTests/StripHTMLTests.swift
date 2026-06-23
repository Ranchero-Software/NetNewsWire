//
//  StripHTMLTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 2025-10-20.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing

struct StripHTMLTests {

	@Test func basic() {
		#expect("<p>Hello <b>world</b>!</p>".strippingHTML() == "Hello world!")
	}

	@Test func withScript() {
		#expect("<p>Before</p><script>alert('test');</script><p>After</p>".strippingHTML() == "Before After")
	}

	@Test func withStyle() {
		#expect("<p>Content</p><style>body { color: red; }</style><p>More</p>".strippingHTML() == "Content More")
	}

	@Test func withMaxCharacters() {
		let html = "<p>This is a long piece of text that should be truncated at some point.</p>"
		let result = html.strippingHTML(maxCharacters: 20)
		#expect(result.count <= 20)
		#expect(result == "This is a long piece")
	}

	@Test func withUTF8() {
		#expect("<p>Hello 世界 🌍</p>".strippingHTML() == "Hello 世界 🌍")
	}

	@Test func whitespaceCollapsing() {
		let result = "<p>Too     many\n\n\nspaces</p>".strippingHTML()
		#expect(!result.contains("  "))
		#expect(result == "Too many spaces")
	}

	@Test func scriptAndStyleAreCaseInsensitive() {
		#expect("<p>Before</p><SCRIPT>alert('x');</SCRIPT><P>After</P>".strippingHTML() == "Before After")
		#expect("<p>x</p><STYLE>body{}</STYLE><p>y</p>".strippingHTML() == "x y")
		#expect("<Script>ignored</Script>visible".strippingHTML() == "visible")
	}

	@Test func plainText() {
		#expect("  hello   world  ".strippingHTML() == "hello world")
		#expect("no html here".strippingHTML() == "no html here")
		#expect("\n\ttabs and\nnewlines\n".strippingHTML() == "tabs and newlines")
	}

	@Test func doesNotDecodeEntities() {
		#expect("<p>A &amp; B</p>".strippingHTML() == "A &amp; B")
		#expect("<p>&lt;3 &gt;9 &quot;q&quot;</p>".strippingHTML() == "&lt;3 &gt;9 &quot;q&quot;")
		#expect("<p>&#169; &#x2014;</p>".strippingHTML() == "&#169; &#x2014;")
	}

	@Test func emptyString() {
		#expect("".strippingHTML() == "")
		#expect("".strippingHTML(maxCharacters: 10) == "")
		#expect("".strippingHTML(maxCharacters: 0) == "")
	}

	@Test func blockTagsInjectSpaces() {
		#expect("a<br>b".strippingHTML() == "a b")
		#expect("a<br/>b".strippingHTML() == "a b")
		#expect("a<br />b".strippingHTML() == "a b")
		#expect("<div>a</div><div>b</div>".strippingHTML() == "a b")
		#expect("<blockquote>a</blockquote><blockquote>b</blockquote>".strippingHTML() == "a b")
		#expect("<ul><li>a</li><li>b</li></ul>".strippingHTML() == "a b")
		#expect("<p>a</p><p>b</p>".strippingHTML() == "a b")
		// Adjacent block-tag-injected spaces don't double up.
		#expect("<p>a</p><div>b</div>".strippingHTML() == "a b")
	}

	@Test func maxCharactersBoundaries() {
		let source = "hello world"
		#expect(source.strippingHTML(maxCharacters: nil) == "hello world")
		#expect(source.strippingHTML(maxCharacters: 0) == "hello world")
		#expect(source.strippingHTML(maxCharacters: 1) == "h")
		#expect(source.strippingHTML(maxCharacters: 5) == "hello")
		#expect(source.strippingHTML(maxCharacters: 100) == "hello world")
	}

	@Test func nestedTags() {
		#expect("<div><div><div>x</div></div></div>".strippingHTML() == "x")
		#expect("<b><i><u>deeply nested</u></i></b>".strippingHTML() == "deeply nested")
		#expect("<a href=\"#\"><span>link</span></a>".strippingHTML() == "link")
	}

	@Test(arguments: ["daringfireball", "apple", "inessential", "scripting"])
	func withRealWorldHTML(testFile: String) throws {
		let url = try #require(Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources"))
		let html = try String(contentsOf: url, encoding: .utf8)
		let result = html.strippingHTML(maxCharacters: 300)

		#expect(!result.isEmpty, "Result should not be empty")
		#expect(result.count <= 300, "Result should respect maxCharacters")
		#expect(!result.contains("<"), "Result should not contain HTML tags")
		#expect(!result.contains("//"), "Should fully remove script content")
	}

	@Test(arguments: ["apple", "daringfireball", "inessential", "scripting"])
	func matchesExpectedOutput(testFile: String) throws {
		let htmlURL = try #require(Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources"))
		let txtURL = try #require(Bundle.module.url(forResource: testFile, withExtension: "txt", subdirectory: "Resources"))

		let html = try String(contentsOf: htmlURL, encoding: .utf8)
		let expectedOutput = try String(contentsOf: txtURL, encoding: .utf8)

		#expect(html.strippingHTML() == expectedOutput, "Implementation should match expected output")
	}

	// Un-comment this to regenerate the .txt files containing expected stripped-HTML results.
	//	@Test func regenerateExpectedOutputFiles() throws {
	//		let testFiles = ["apple", "daringfireball", "inessential", "scripting"]
	//		for testFile in testFiles {
	//			let htmlURL = try #require(Bundle.module.url(forResource: testFile, withExtension: "html", subdirectory: "Resources"))
	//			let html = try String(contentsOf: htmlURL, encoding: .utf8)
	//			let result = html.strippingHTML()
	//			print("\n=== \(testFile) ===")
	//			print("Result length: \(result.count) characters")
	//			print("First 200 chars: \(String(result.prefix(200)))")
	//			let tmpPath = "/tmp/\(testFile).txt"
	//			try result.write(toFile: tmpPath, atomically: true, encoding: .utf8)
	//			print("Wrote to: \(tmpPath)")
	//		}
	//		print("\n\nTo update the expected output files, run:")
	//		print("cp /tmp/apple.txt Tests/RSCoreTests/Resources/")
	//		print("cp /tmp/daringfireball.txt Tests/RSCoreTests/Resources/")
	//		print("cp /tmp/inessential.txt Tests/RSCoreTests/Resources/")
	//		print("cp /tmp/scripting.txt Tests/RSCoreTests/Resources/")
	//	}
}
