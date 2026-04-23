//
//  SanitizedTitleTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing

@testable import NetNewsWire

/// Tests for `ArticleStringFormatter.sanitizedTitle(_:forHTML:)`.
@Suite struct SanitizedTitleTests {

	// MARK: - No tags

	@Test("Plain text passes through unchanged in both modes",
	      arguments: [true, false])
	func plainTextPreserved(forHTML: Bool) {
		#expect(ArticleStringFormatter.sanitizedTitle("Hello World", forHTML: forHTML) == "Hello World")
	}

	@Test("Empty string returns empty string in both modes",
	      arguments: [true, false])
	func emptyString(forHTML: Bool) {
		#expect(ArticleStringFormatter.sanitizedTitle("", forHTML: forHTML) == "")
	}

	@Test("Nil title returns nil in both modes",
	      arguments: [true, false])
	func nilTitleReturnsNil(forHTML: Bool) {
		#expect(ArticleStringFormatter.sanitizedTitle(nil, forHTML: forHTML) == nil)
	}

	// MARK: - Allowed tags (b, i, em, etc.)

	@Test func allowedTagForHTMLIsPreserved() {
		#expect(ArticleStringFormatter.sanitizedTitle("Use <b>bold</b>", forHTML: true) == "Use <b>bold</b>")
	}

	@Test func allowedTagNotForHTMLIsStripped() {
		#expect(ArticleStringFormatter.sanitizedTitle("Use <b>bold</b>", forHTML: false) == "Use bold")
	}

	@Test func multipleAllowedTagsForHTML() {
		#expect(
			ArticleStringFormatter.sanitizedTitle("<b>Bold</b> and <i>italic</i>", forHTML: true)
			== "<b>Bold</b> and <i>italic</i>"
		)
	}

	@Test func multipleAllowedTagsNotForHTML() {
		#expect(
			ArticleStringFormatter.sanitizedTitle("<b>Bold</b> and <i>italic</i>", forHTML: false)
			== "Bold and italic"
		)
	}

	// MARK: - Disallowed tags (script, div, etc.)

	@Test("Disallowed tag is escaped with forHTML=true so it renders as text")
	func disallowedTagForHTMLIsEscaped() {
		#expect(
			ArticleStringFormatter.sanitizedTitle("Use <script>evil</script>", forHTML: true)
			== "Use &lt;script&gt;evil&lt;/script&gt;"
		)
	}

	// Disallowed tags with forHTML=false are passed through literally.
	// Callers (specifically `strippingHTML`) may remove them later.
	@Test func disallowedTagNotForHTMLIsPreservedLiterally() {
		#expect(
			ArticleStringFormatter.sanitizedTitle("Use <script>evil</script>", forHTML: false)
			== "Use <script>evil</script>"
		)
	}

	// MARK: - Slash handling

	// The implementation strips ALL slashes from the tag name before
	// looking it up in the allowed set. That means `</b>` → "b"
	// (allowed), `<b/>` → "b" (allowed), `<br/>` → "br" (not allowed).

	@Test("<b/> normalizes to b (allowed) — preserved under forHTML",
	      arguments: [
		      (true, "X<b/>Y"),
		      (false, "XY")
	      ])
	func selfClosingAllowedTag(forHTML: Bool, expected: String) {
		#expect(ArticleStringFormatter.sanitizedTitle("X<b/>Y", forHTML: forHTML) == expected)
	}

	@Test("<br/> normalizes to br (not allowed) — escaped or passed through",
	      arguments: [
		      (true, "X&lt;br/&gt;Y"),
		      (false, "X<br/>Y")
	      ])
	func selfClosingDisallowedTag(forHTML: Bool, expected: String) {
		#expect(ArticleStringFormatter.sanitizedTitle("X<br/>Y", forHTML: forHTML) == expected)
	}

	// MARK: - Malformed input

	// Unclosed tag (no `>` to terminate). We scan to end of input as
	// the tag body and still emit closing punctuation — a slightly
	// weird but stable behavior inherited from the Scanner-based
	// predecessor, which tests pinned to preserve.

	@Test("Unclosed tag with forHTML=false emits literal `<tag>` with synthesized `>`")
	func unclosedTagNotForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("foo <bar", forHTML: false) == "foo <bar>")
	}

	@Test("Unclosed tag with forHTML=true emits escaped `&lt;tag&gt;`")
	func unclosedTagForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("foo <bar", forHTML: true) == "foo &lt;bar&gt;")
	}

	// Bare `<` at end of input: no tag body, emit nothing for it.
	@Test(arguments: [true, false])
	func bareLessThanAtEnd(forHTML: Bool) {
		#expect(ArticleStringFormatter.sanitizedTitle("foo <", forHTML: forHTML) == "foo ")
	}

	// MARK: - Unicode

	@Test("Plain Unicode content passes through verbatim in both modes",
	      arguments: [true, false])
	func unicodeContentPreserved(forHTML: Bool) {
		let input = "Café résumé with emoji 🎉"
		#expect(ArticleStringFormatter.sanitizedTitle(input, forHTML: forHTML) == input)
	}

	@Test func unicodeInsideAllowedTagForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("<b>Café</b>", forHTML: true) == "<b>Café</b>")
	}

	@Test func unicodeInsideAllowedTagNotForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("<b>Café</b>", forHTML: false) == "Café")
	}
}
