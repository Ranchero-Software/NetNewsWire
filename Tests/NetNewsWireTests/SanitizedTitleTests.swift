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

	// MARK: - abbr (issue #3325)

	// The Register and similar feeds put `<abbr title="…">` in titles.
	// The tag is matched by name (attributes ignored), so it's recognized
	// as an allowed tag rather than shown as raw markup.

	@Test("abbr with attribute is preserved under forHTML (real element in detail pane)")
	func abbrWithAttributeForHTML() {
		#expect(
			ArticleStringFormatter.sanitizedTitle("[<abbr title=\"Not Safe For Work\">NSFW</abbr>]", forHTML: true)
			== "[<abbr title=\"Not Safe For Work\">NSFW</abbr>]"
		)
	}

	@Test("abbr with attribute is dropped under forHTML=false, contents kept")
	func abbrWithAttributeNotForHTML() {
		#expect(
			ArticleStringFormatter.sanitizedTitle("[<abbr title=\"Not Safe For Work\">NSFW</abbr>]", forHTML: false)
			== "[NSFW]"
		)
	}

	// Matching is by tag name, so an allowed tag carrying an attribute
	// is still recognized (previously it was matched whole-body and
	// treated as disallowed).

	@Test func allowedTagWithAttributeForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("<cite id=\"x\">Book</cite>", forHTML: true) == "<cite id=\"x\">Book</cite>")
	}

	@Test func allowedTagWithAttributeNotForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("<cite id=\"x\">Book</cite>", forHTML: false) == "Book")
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

	// Unclosed tag (no `>` to terminate). The `<` and its trailing text
	// are kept, but no closing `>` is synthesized — so a literal `<`
	// followed by text stays faithful to the input (issue #4742).

	@Test("Unclosed tag with forHTML=false keeps `<tag`, no synthesized `>`")
	func unclosedTagNotForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("foo <bar", forHTML: false) == "foo <bar")
	}

	@Test("Unclosed tag with forHTML=true escapes `<` and keeps text, no synthesized `>`")
	func unclosedTagForHTML() {
		#expect(ArticleStringFormatter.sanitizedTitle("foo <bar", forHTML: true) == "foo &lt;bar")
	}

	// #4742: a title with a literal `<` (from an entity like `&#x3C;`)
	// followed by non-tag text — here `<16s` — must not be truncated at
	// the `<`, and must not gain a spurious trailing `>`. The whole
	// title survives; the `<` is escaped so `simpleHTML` shows it as text.
	@Test func literalLessThanInTitleIsNotTruncated() {
		let input = "No place in children's hands: <16s in UK to be banned"
		#expect(
			ArticleStringFormatter.sanitizedTitle(input, forHTML: true)
			== "No place in children's hands: &lt;16s in UK to be banned"
		)
		#expect(
			ArticleStringFormatter.sanitizedTitle(input, forHTML: false)
			== "No place in children's hands: <16s in UK to be banned"
		)
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
