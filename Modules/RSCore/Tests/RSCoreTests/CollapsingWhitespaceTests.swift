//
//  CollapsingWhitespaceTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Testing
@testable import RSCore

/// Correctness tests for `String.collapsingWhitespace`. The function
/// trims leading/trailing ASCII whitespace and collapses internal runs
/// of ASCII whitespace to a single space, matching the pre-existing
/// regex `\s` semantics (ASCII-only, Unicode whitespace like NBSP
/// passes through).
@Suite struct CollapsingWhitespaceTests {

	// MARK: - Edge cases

	@Test func emptyString() {
		#expect("".collapsingWhitespace == "")
	}

	@Test("Whitespace-only input collapses to empty",
	      arguments: ["   ", "\t\t\t", "\n\n", "\r\n", " \t\n\r"])
	func onlyWhitespaceCollapsesToEmpty(_ input: String) {
		#expect(input.collapsingWhitespace == "")
	}

	@Test func singleCharacter() {
		#expect("x".collapsingWhitespace == "x")
	}

	// MARK: - Trimming

	@Test func leadingWhitespaceIsStripped() {
		#expect("   hello".collapsingWhitespace == "hello")
	}

	@Test func trailingWhitespaceIsStripped() {
		#expect("hello   ".collapsingWhitespace == "hello")
	}

	@Test func leadingAndTrailingWhitespaceStripped() {
		#expect("   hello   ".collapsingWhitespace == "hello")
	}

	// MARK: - Collapsing

	@Test func alreadyCleanStringPassesThrough() {
		#expect("one two three".collapsingWhitespace == "one two three")
	}

	@Test func multiSpaceRunsCollapseToSingleSpace() {
		#expect("one     two".collapsingWhitespace == "one two")
	}

	// All six ASCII whitespace characters matched by
	// `NSRegularExpression`'s `\s`: space, tab, LF, VT, FF, CR.
	@Test("Each ASCII whitespace character collapses a word boundary",
	      arguments: [
		      ("a b", "a b"),
		      ("a\tb", "a b"),
		      ("a\nb", "a b"),
		      ("a\u{0B}b", "a b"),  // vertical tab
		      ("a\u{0C}b", "a b"),  // form feed
		      ("a\rb", "a b"),
		      ("a \t\n\u{0B}\u{0C}\r b", "a b")
	      ])
	func asciiWhitespaceCharacters(_ input: String, _ expected: String) {
		#expect(input.collapsingWhitespace == expected)
	}

	// MARK: - Unicode

	// NBSP is Unicode whitespace but not matched by ASCII `\s`, so it
	// passes through verbatim — same behavior as the pre-existing
	// regex implementation.
	@Test func nonBreakingSpaceIsPreserved() {
		let nbsp = "\u{00A0}"
		#expect("a\(nbsp)b".collapsingWhitespace == "a\(nbsp)b")
	}

	@Test func unicodeContentPassesThrough() {
		#expect("Café résumé 🎉".collapsingWhitespace == "Café résumé 🎉")
	}

	@Test func unicodeContentWithInternalWhitespaceIsCollapsed() {
		#expect("Café   résumé".collapsingWhitespace == "Café résumé")
	}

	// MARK: - Mixed real-world input

	@Test func mixedWhitespaceAndText() {
		let input = "   lots\t\tof   random\n\nwhitespace\r\n"
		#expect(input.collapsingWhitespace == "lots of random whitespace")
	}
}
