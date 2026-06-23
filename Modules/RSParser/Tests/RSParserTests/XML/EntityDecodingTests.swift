//
//  EntityDecodingTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 12/30/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Testing
import RSParser

@Suite struct EntityDecodingTests {

	@Test("Decimal entity &#39; (single-quote bug from micro.blog)")
	func decimalEntity39() {
		// Bug found by Manton Reece — the &#39; entity was not getting decoded
		// by NetNewsWire in JSON Feeds from micro.blog.
		let s = "These are the times that try men&#39;s souls."
		let decoded = s.decodingHTMLEntities()
		#expect(decoded == "These are the times that try men's souls.")
	}

	@Test("Decimal and hex entities decode to the same characters",
	      arguments: [
	          ("&#8230;", "…"),
	          ("&#x2026;", "…"),
	          ("&#039;", "'"),
	          ("&#167;", "§"),
	          ("&#XA3;", "£")
	      ])
	func entityPair(_ input: String, _ expected: String) {
		#expect(input.decodingHTMLEntities() == expected)
	}

	// MARK: - Predefined XML entities (required by every parser without a DTD)

	@Test("All five predefined XML entities decode individually",
	      arguments: [
	          ("&amp;", "&"),
	          ("&lt;", "<"),
	          ("&gt;", ">"),
	          ("&quot;", "\""),
	          ("&apos;", "'")
	      ])
	func predefinedXMLEntity(_ input: String, _ expected: String) {
		#expect(input.decodingHTMLEntities() == expected)
	}

	@Test("Predefined XML entities decode when embedded in surrounding text") func predefinedXMLEntitiesInContext() {
		#expect("Tom &amp; Jerry".decodingHTMLEntities() == "Tom & Jerry")
		#expect("&lt;script&gt;alert(1)&lt;/script&gt;".decodingHTMLEntities() == "<script>alert(1)</script>")
		#expect("He said &quot;hi&quot;".decodingHTMLEntities() == "He said \"hi\"")
		#expect("it&apos;s".decodingHTMLEntities() == "it's")
	}

	// MARK: - Malformed entities pass through literally

	// "Pass through" here means: the raw characters must appear verbatim in
	// the output, exactly as they were in the input. libxml2 behavior; our
	// Swift decoder is intentionally the same.

	@Test func unknownNamedEntityPassesThrough() {
		// Unknown entity: the entity spelling stays literal.
		#expect("&foo;".decodingHTMLEntities() == "&foo;")
		#expect("hello &bogus; world".decodingHTMLEntities() == "hello &bogus; world")
	}

	@Test func entityWithoutSemicolonPassesThrough() {
		// Malformed (no `;`): the whole chunk stays as-is.
		#expect("&amp".decodingHTMLEntities() == "&amp")
		#expect("a&amp b".decodingHTMLEntities() == "a&amp b")
	}

	@Test func emptyEntityReferencePassesThrough() {
		// `&;` is not a valid entity — leave it alone.
		#expect("&;".decodingHTMLEntities() == "&;")
	}

	@Test func lonelyAmpersandPassesThrough() {
		// Bare `&` with nothing after it.
		#expect("&".decodingHTMLEntities() == "&")
		#expect("a & b".decodingHTMLEntities() == "a & b")
	}

	@Test func malformedNumericEntitiesPassThrough() {
		// `&#;` and `&#x;` have no digits.
		#expect("&#;".decodingHTMLEntities() == "&#;")
		#expect("&#x;".decodingHTMLEntities() == "&#x;")
		// Non-digit body.
		#expect("&#abc;".decodingHTMLEntities() == "&#abc;")
		#expect("&#xZZ;".decodingHTMLEntities() == "&#xZZ;")
	}

	// MARK: - Numeric entity edge cases

	@Test func numericEntityZeroPassesThrough() {
		// Codepoint 0 is not representable — decoder treats it as malformed.
		#expect("&#0;".decodingHTMLEntities() == "&#0;")
		#expect("&#x0;".decodingHTMLEntities() == "&#x0;")
	}

	@Test func numericEntityOutOfRangePassesThrough() {
		// Valid Unicode is 0x0 … 0x10FFFF. Anything above must not decode.
		#expect("&#x110000;".decodingHTMLEntities() == "&#x110000;")
		#expect("&#99999999;".decodingHTMLEntities() == "&#99999999;")
	}

	@Test("Windows Latin-1 extension remap (128-159 → Windows-1252 codepoints)",
	      arguments: [
	          // Historical HTML authors typed `&#128;` expecting the Windows-1252
	          // codepoint (€) even though U+0080 is a C1 control character.
	          // WebKit's HTMLEntityParser applies this remap; our decoder matches.
	          ("&#128;", "€"),   // 0x80 → U+20AC EURO SIGN
	          ("&#130;", "‚"),   // 0x82 → U+201A
	          ("&#133;", "…"),   // 0x85 → U+2026 HORIZONTAL ELLIPSIS
	          ("&#134;", "†"),   // 0x86 → U+2020 DAGGER
	          ("&#145;", "‘"),   // 0x91 → U+2018 LEFT SINGLE QUOTATION MARK
	          ("&#146;", "’"),   // 0x92 → U+2019 RIGHT SINGLE QUOTATION MARK
	          ("&#147;", "“"),   // 0x93 → U+201C LEFT DOUBLE QUOTATION MARK
	          ("&#148;", "”"),   // 0x94 → U+201D RIGHT DOUBLE QUOTATION MARK
	          ("&#150;", "–"),   // 0x96 → U+2013 EN DASH
	          ("&#151;", "—"),   // 0x97 → U+2014 EM DASH
	          ("&#153;", "™"),   // 0x99 → U+2122 TRADE MARK SIGN
	          // Hex spelling must be remapped the same way.
	          ("&#x80;", "€"),
	          ("&#x96;", "–")
	      ])
	func windowsLatin1Remap(_ input: String, _ expected: String) {
		#expect(input.decodingHTMLEntities() == expected)
	}

	// MARK: - Mixed and chained entities

	@Test func multipleConsecutiveEntities() {
		#expect("&amp;&lt;&gt;".decodingHTMLEntities() == "&<>")
		#expect("&#8220;&#8221;".decodingHTMLEntities() == "“”")
	}

	@Test func entitiesMixedWithPlainText() {
		let input = "One &amp; two: &#8216;three&#8217; — &#x2014; &mdash;."
		let expected = "One & two: ‘three’ — — —."
		#expect(input.decodingHTMLEntities() == expected)
	}

	@Test func stringWithNoEntitiesUnchanged() {
		// Fast-path case: no `&` in input, returned unchanged.
		let input = "Just some text with no entities at all."
		#expect(input.decodingHTMLEntities() == input)
	}

	@Test func emptyStringUnchanged() {
		#expect("".decodingHTMLEntities() == "")
	}

	// MARK: - Hex-digit case, boundary, and 4-byte UTF-8 (Tier 2 pinning)

	@Test func hexEntityIsCaseInsensitiveForDigits() {
		// Hex digits a-f and A-F must both decode the same. Pin as a paired
		// test — if only one case works, the assertion pair fails rather than
		// one or the other silently passing.
		let lower = "&#xab;".decodingHTMLEntities()
		let upper = "&#xAB;".decodingHTMLEntities()
		#expect(lower == upper)
		#expect(lower == "«") // U+00AB
		// Mixed case too.
		#expect("&#xAb;".decodingHTMLEntities() == "«")
		#expect("&#xaB;".decodingHTMLEntities() == "«")
		// The `x` itself may also be uppercase (`&#X…;`).
		#expect("&#X2026;".decodingHTMLEntities() == "…")
	}

	@Test func entityAtEndOfInputBoundary() {
		// Entity with trailing semicolon right at EOF decodes.
		#expect("foo&amp;".decodingHTMLEntities() == "foo&")
		// Entity with no semicolon and no more input passes through literally
		// (scanner must not walk off the end of the buffer).
		#expect("foo&amp".decodingHTMLEntities() == "foo&amp")
		// Bare `&` at EOF.
		#expect("foo&".decodingHTMLEntities() == "foo&")
		// Numeric entity at EOF with no digits.
		#expect("foo&#".decodingHTMLEntities() == "foo&#")
		#expect("foo&#x".decodingHTMLEntities() == "foo&#x")
	}

	@Test func fourByteUTF8EmojiDecodes() {
		// High codepoints need 4-byte UTF-8 encoding. Exercises the full
		// encode-as-UTF-8 path in the decoder, not the 1/2/3-byte shortcuts.
		#expect("&#x1F600;".decodingHTMLEntities() == "😀") // U+1F600
		#expect("&#128512;".decodingHTMLEntities() == "😀") // decimal form
		#expect("&#x1F44B;".decodingHTMLEntities() == "👋") // U+1F44B
		// Round-trip: the decoded string's UTF-8 should be the canonical
		// 4-byte sequence for 😀 (0xF0 0x9F 0x98 0x80).
		let bytes = Array("&#x1F600;".decodingHTMLEntities().utf8)
		#expect(bytes == [0xF0, 0x9F, 0x98, 0x80])
	}
}
