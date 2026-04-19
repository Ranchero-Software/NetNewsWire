//
//  XMLEntitiesTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import Foundation
import Testing
@testable import RSParser

// Unit tests for XMLEntities.decode. The scanner also exercises this code end-to-end
// via feed parsing, but these tests pin down the contract at the single-entity level.

@Suite struct XMLEntitiesTests {

	// MARK: - Helpers

	/// Decode a single entity at the start of `input` and return the decoded UTF-8 as a String.
	private func decodeOne(_ input: String, mode: XMLEntities.Mode = .normal) -> (text: String, nextIndex: Int) {
		let bytes = Array(input.utf8)
		let result = XMLEntities.decode(bytes: bytes, at: 0, mode: mode)
		return (String(decoding: result.bytes, as: UTF8.self), result.nextIndex)
	}

	// MARK: - Predefined XML entities

	@Test("The five predefined XML entities expand in .normal mode",
	      arguments: [
	          ("&amp;", "&"),
	          ("&lt;", "<"),
	          ("&gt;", ">"),
	          ("&quot;", "\""),
	          ("&apos;", "'")
	      ])
	func predefinedEntitiesNormalMode(_ input: String, _ expected: String) {
		let (text, nextIndex) = decodeOne(input)
		#expect(text == expected)
		#expect(nextIndex == input.utf8.count)
	}

	@Test("The five predefined XML entities stay literal in .preservePredefinedXML mode",
	      arguments: ["&amp;", "&lt;", "&gt;", "&quot;", "&apos;"])
	func predefinedEntitiesPreserveMode(_ input: String) {
		let (text, nextIndex) = decodeOne(input, mode: .preservePredefinedXML)
		// Returns a bare `&` and advances only past the `&` so the caller can re-emit the literal.
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	// MARK: - Numeric entities — decimal

	@Test("Decimal numeric entities decode",
	      arguments: [
	          ("&#65;", "A"),
	          ("&#8482;", "\u{2122}"),        // ™
	          ("&#8220;", "\u{201C}"),        // “
	          ("&#9731;", "\u{2603}")         // ☃
	      ])
	func decimalNumericEntities(_ input: String, _ expected: String) {
		let (text, nextIndex) = decodeOne(input)
		#expect(text == expected)
		#expect(nextIndex == input.utf8.count)
	}

	@Test func decimalZeroIsRejected() {
		let (text, nextIndex) = decodeOne("&#0;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func decimalWithNonDigitIsRejected() {
		let (text, nextIndex) = decodeOne("&#12a;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func decimalEmptyIsRejected() {
		let (text, nextIndex) = decodeOne("&#;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	// MARK: - Numeric entities — hex

	@Test("Hex numeric entities decode",
	      arguments: [
	          ("&#x41;", "A"),
	          ("&#X41;", "A"),                 // uppercase X accepted
	          ("&#x2014;", "\u{2014}"),        // —
	          ("&#xAD;", "\u{00AD}"),          // soft hyphen
	          ("&#x1F600;", "\u{1F600}")       // 😀 (4-byte UTF-8)
	      ])
	func hexNumericEntities(_ input: String, _ expected: String) {
		let (text, nextIndex) = decodeOne(input)
		#expect(text == expected)
		#expect(nextIndex == input.utf8.count)
	}

	@Test func hexZeroIsRejected() {
		let (text, nextIndex) = decodeOne("&#x0;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func hexEmptyIsRejected() {
		let (text, nextIndex) = decodeOne("&#x;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func hexWithNonHexIsRejected() {
		let (text, nextIndex) = decodeOne("&#xZZ;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	// MARK: - Surrogate and out-of-range codepoints

	@Test("Surrogate codepoints are rejected",
	      arguments: ["&#xD800;", "&#xDC00;", "&#xDFFF;", "&#55296;"]) // 0xD800 decimal
	func surrogatesRejected(_ input: String) {
		let (text, nextIndex) = decodeOne(input)
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func outOfRangeCodepointRejected() {
		// 0x110000 — one past the maximum Unicode codepoint.
		let (text, nextIndex) = decodeOne("&#x110000;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	// MARK: - Windows-1252 remap

	@Test("Codepoints in [0x80, 0x9F] are remapped via Windows-1252 extension",
	      arguments: [
	          ("&#128;", "\u{20AC}"),   // €
	          ("&#133;", "\u{2026}"),   // …
	          ("&#145;", "\u{2018}"),   // ‘
	          ("&#146;", "\u{2019}"),   // ’
	          ("&#147;", "\u{201C}"),   // “
	          ("&#148;", "\u{201D}"),   // ”
	          ("&#150;", "\u{2013}"),   // –
	          ("&#151;", "\u{2014}"),   // —
	          ("&#153;", "\u{2122}")    // ™
	      ])
	func windows1252Remap(_ input: String, _ expected: String) {
		let (text, _) = decodeOne(input)
		#expect(text == expected)
	}

	@Test("Codepoint 0x7F and 0xA0 are NOT remapped (boundary check)")
	func windows1252BoundariesNotRemapped() {
		// 0x7F DEL — below the remap range.
		var (text, _) = decodeOne("&#x7F;")
		#expect(text == "\u{007F}")
		// 0xA0 NBSP — above the remap range.
		(text, _) = decodeOne("&#xA0;")
		#expect(text == "\u{00A0}")
	}

	// MARK: - HTML named entities

	@Test("Common HTML named entities expand",
	      arguments: [
	          ("&copy;", "©"),
	          ("&mdash;", "—"),
	          ("&ndash;", "–"),
	          ("&ldquo;", "“"),
	          ("&rdquo;", "”"),
	          ("&hellip;", "…"),
	          ("&trade;", "™"),
	          ("&eacute;", "é"),
	          ("&nbsp;", "\u{00A0}"),
	          ("&shy;", "\u{00AD}")
	      ])
	func htmlNamedEntities(_ input: String, _ expected: String) {
		let (text, nextIndex) = decodeOne(input)
		#expect(text == expected)
		#expect(nextIndex == input.utf8.count)
	}

	@Test func longestHTMLNamedEntity() {
		// CounterClockwiseContourIntegral is our longest entry — confirms we
		// don't accidentally trip `maxEntityLength` on it.
		let (text, _) = decodeOne("&CounterClockwiseContourIntegral;")
		#expect(text == "∳")
	}

	@Test("HTML named entities are case-sensitive")
	func htmlNamedEntityCaseSensitive() {
		// `copy` exists; `COPY` doesn't. (Some uppercase variants like `AElig` do exist.)
		let (text, nextIndex) = decodeOne("&COPY;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test("Uppercase HTML entities expand (case-sensitive, distinct entry)")
	func htmlNamedEntityUppercase() {
		// AElig is present in the table with its own mapping.
		let (text, _) = decodeOne("&AElig;")
		#expect(text == "Æ")
	}

	@Test func unknownHTMLNamedEntityIsRejected() {
		let (text, nextIndex) = decodeOne("&notARealEntity;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	// MARK: - Malformed inputs

	@Test func noSemicolonReturnsLiteral() {
		let (text, nextIndex) = decodeOne("&amp")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func emptyEntityReturnsLiteral() {
		// `&;` — no name at all.
		let (text, nextIndex) = decodeOne("&;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test("Whitespace terminates the scan before `;`",
	      arguments: ["&amp ", "&amp\t", "&amp\n"])
	func whitespaceTerminatesScan(_ input: String) {
		let (text, nextIndex) = decodeOne(input)
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func nestedAmpersandTerminatesScan() {
		// `&amp&lt;` — the inner `&` ends the scan for the outer entity.
		let (text, nextIndex) = decodeOne("&amp&lt;")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func lessThanTerminatesScan() {
		// `&amp<` — scanner stops because `<` is illegal inside an entity name.
		let (text, nextIndex) = decodeOne("&amp<")
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	@Test func tooLongEntityIsRejected() {
		// More than maxEntityLength bytes before the `;` — refuses to scan further.
		let longName = String(repeating: "x", count: 100)
		let input = "&\(longName);"
		let (text, nextIndex) = decodeOne(input)
		#expect(text == "&")
		#expect(nextIndex == 1)
	}

	// MARK: - `at` parameter honored

	@Test func decodesAtNonZeroIndex() {
		// Entity in the middle of a byte buffer.
		let bytes = Array("Hello &amp; world".utf8)
		let ampIndex = 6 // position of `&`
		let result = XMLEntities.decode(bytes: bytes, at: ampIndex, mode: .normal)
		#expect(String(decoding: result.bytes, as: UTF8.self) == "&")
		#expect(result.nextIndex == ampIndex + 5) // past `&amp;`
	}

	// MARK: - Modes don't affect numeric or HTML named entities

	@Test func preserveModeStillExpandsNumericEntities() {
		let (text, _) = decodeOne("&#65;", mode: .preservePredefinedXML)
		#expect(text == "A")
	}

	@Test func preserveModeStillExpandsHTMLNamedEntities() {
		let (text, _) = decodeOne("&copy;", mode: .preservePredefinedXML)
		#expect(text == "©")
	}

	// MARK: - Windows-1252 extension table exposure

	@Test func windowsLatin1ExtensionTableSize() {
		#expect(XMLEntities.windowsLatin1Extension.count == 32)
	}

	@Test func windowsLatin1ExtensionKnownEntries() {
		#expect(XMLEntities.windowsLatin1Extension[0] == 0x20AC)   // €
		#expect(XMLEntities.windowsLatin1Extension[0x99 - 0x80] == 0x2122) // ™
	}
}
