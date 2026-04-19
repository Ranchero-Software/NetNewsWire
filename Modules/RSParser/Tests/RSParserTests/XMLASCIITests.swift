//
//  XMLASCIITests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//
//  Tests for the UInt8 ASCII helpers and ArraySlice<UInt8> comparison methods
//  in XMLASCII.swift. These underpin the scanner so every code path should
//  be pinned down by a test.
//

import Foundation
import Testing
@testable import RSParser

@Suite struct XMLASCIITests {

	// MARK: - Byte constants

	@Test func byteConstantsMatchLiterals() {
		#expect(UInt8.asciiTab == 0x09)
		#expect(UInt8.asciiNewline == 0x0A)
		#expect(UInt8.asciiCarriageReturn == 0x0D)
		#expect(UInt8.asciiSpace == 0x20)
		#expect(UInt8.asciiExclamation == 0x21)
		#expect(UInt8.asciiDoubleQuote == 0x22)
		#expect(UInt8.asciiAmpersand == 0x26)
		#expect(UInt8.asciiLessThan == 0x3C)
		#expect(UInt8.asciiGreaterThan == 0x3E)
		#expect(UInt8.ascii0 == 0x30)
		#expect(UInt8.ascii9 == 0x39)
		#expect(UInt8.asciiUpperA == 0x41)
		#expect(UInt8.asciiLowerA == 0x61)
		#expect(UInt8.asciiLowerZ == 0x7A)
	}

	// MARK: - isASCIIWhitespace

	@Test("Whitespace bytes are recognized",
	      arguments: [UInt8.asciiSpace, UInt8.asciiTab, UInt8.asciiNewline, UInt8.asciiCarriageReturn])
	func whitespaceIsRecognized(_ b: UInt8) {
		#expect(b.isASCIIWhitespace)
	}

	@Test("Non-whitespace bytes are rejected",
	      arguments: [UInt8(ascii: "A"), UInt8(ascii: "0"), UInt8(ascii: "_"),
	                  UInt8(ascii: "<"), 0x00, 0x0B, 0x0C, 0xFF])
	func nonWhitespaceIsRejected(_ b: UInt8) {
		#expect(!b.isASCIIWhitespace)
	}

	// MARK: - isASCIIDigit

	@Test func digitsRecognized() {
		for c in UInt8(ascii: "0")...UInt8(ascii: "9") {
			#expect(c.isASCIIDigit)
		}
	}

	@Test("Non-digit bytes are rejected",
	      arguments: [UInt8(ascii: "A"), UInt8(ascii: "a"), UInt8(ascii: "/"),
	                  UInt8(ascii: ":"), UInt8(ascii: " "), 0x00, 0xFF])
	func nonDigitIsRejected(_ b: UInt8) {
		#expect(!b.isASCIIDigit)
	}

	// MARK: - isASCIILetter

	@Test func lettersRecognized() {
		for c in UInt8(ascii: "A")...UInt8(ascii: "Z") {
			#expect(c.isASCIILetter)
		}
		for c in UInt8(ascii: "a")...UInt8(ascii: "z") {
			#expect(c.isASCIILetter)
		}
	}

	@Test("Non-letter bytes are rejected",
	      arguments: [UInt8(ascii: "0"), UInt8(ascii: "9"), UInt8(ascii: "@"),
	                  UInt8(ascii: "["), UInt8(ascii: "`"), UInt8(ascii: "{"),
	                  UInt8(ascii: "-"), 0x00, 0xFF])
	func nonLetterIsRejected(_ b: UInt8) {
		#expect(!b.isASCIILetter)
	}

	// MARK: - asciiHexValue

	@Test("Decimal digits produce their numeric value",
	      arguments: zip(Array("0123456789".utf8), (0 as UInt32)...9))
	func hexValueForDigits(_ byte: UInt8, _ expected: UInt32) {
		#expect(byte.asciiHexValue == expected)
	}

	@Test("Uppercase hex letters produce 10-15",
	      arguments: zip(Array("ABCDEF".utf8), (10 as UInt32)...15))
	func hexValueForUpperLetters(_ byte: UInt8, _ expected: UInt32) {
		#expect(byte.asciiHexValue == expected)
	}

	@Test("Lowercase hex letters produce 10-15",
	      arguments: zip(Array("abcdef".utf8), (10 as UInt32)...15))
	func hexValueForLowerLetters(_ byte: UInt8, _ expected: UInt32) {
		#expect(byte.asciiHexValue == expected)
	}

	@Test("Non-hex bytes return nil — including bytes near the hex range",
	      arguments: [
	          UInt8(ascii: "G"), UInt8(ascii: "g"), UInt8(ascii: "Z"),
	          UInt8(ascii: "z"), UInt8(ascii: "@"), UInt8(ascii: "`"),
	          UInt8(ascii: "/"), UInt8(ascii: ":"), UInt8(ascii: " "),
	          0x00, 0xFF
	      ])
	func hexValueForNonHexIsNil(_ b: UInt8) {
		#expect(b.asciiHexValue == nil)
	}

	// Regression test for the `| 0x20` simplification: confirm that no non-letter
	// byte can produce a false positive in the folded range check.
	@Test func hexValueNeverFalsePositiveFromCaseFoldTrick() {
		for b: UInt8 in 0...0xFF {
			let expected: UInt32?
			switch b {
			case UInt8(ascii: "0")...UInt8(ascii: "9"):
				expected = UInt32(b - UInt8(ascii: "0"))
			case UInt8(ascii: "A")...UInt8(ascii: "F"):
				expected = UInt32(b - UInt8(ascii: "A")) + 10
			case UInt8(ascii: "a")...UInt8(ascii: "f"):
				expected = UInt32(b - UInt8(ascii: "a")) + 10
			default:
				expected = nil
			}
			#expect(b.asciiHexValue == expected, "mismatch at byte \(b)")
		}
	}

	// MARK: - asciiLowercased

	@Test("Uppercase letters fold to lowercase",
	      arguments: zip(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8),
	                     Array("abcdefghijklmnopqrstuvwxyz".utf8)))
	func uppercaseFolds(_ upper: UInt8, _ lower: UInt8) {
		#expect(upper.asciiLowercased == lower)
	}

	@Test func lowercaseLettersUnchanged() {
		for c in UInt8(ascii: "a")...UInt8(ascii: "z") {
			#expect(c.asciiLowercased == c)
		}
	}

	@Test("Non-letters pass through unchanged",
	      arguments: [UInt8(ascii: "0"), UInt8(ascii: "9"), UInt8(ascii: "@"),
	                  UInt8(ascii: "["), UInt8(ascii: "`"), UInt8(ascii: "{"),
	                  UInt8(ascii: "/"), UInt8(ascii: "-"), UInt8(ascii: "."),
	                  0x00, 0x7F, 0xFF])
	func nonLettersUnchanged(_ b: UInt8) {
		#expect(b.asciiLowercased == b)
	}

	// MARK: - isXMLNameStart / isXMLNameChar

	@Test("Valid XML name start bytes",
	      arguments: [UInt8(ascii: "a"), UInt8(ascii: "z"), UInt8(ascii: "A"),
	                  UInt8(ascii: "Z"), UInt8(ascii: "_"), UInt8(ascii: ":")])
	func validXMLNameStart(_ b: UInt8) {
		#expect(b.isXMLNameStart)
	}

	@Test("Invalid XML name start bytes",
	      arguments: [UInt8(ascii: "0"), UInt8(ascii: "9"), UInt8(ascii: "-"),
	                  UInt8(ascii: "."), UInt8(ascii: " "), UInt8(ascii: "<"),
	                  UInt8(ascii: "/"), 0x00])
	func invalidXMLNameStart(_ b: UInt8) {
		#expect(!b.isXMLNameStart)
	}

	@Test("Valid XML name continuation bytes include digits, hyphen, dot",
	      arguments: [UInt8(ascii: "a"), UInt8(ascii: "Z"), UInt8(ascii: "_"),
	                  UInt8(ascii: ":"), UInt8(ascii: "0"), UInt8(ascii: "9"),
	                  UInt8(ascii: "-"), UInt8(ascii: ".")])
	func validXMLNameChar(_ b: UInt8) {
		#expect(b.isXMLNameChar)
	}

	@Test("Invalid XML name continuation bytes",
	      arguments: [UInt8(ascii: " "), UInt8(ascii: "<"), UInt8(ascii: ">"),
	                  UInt8(ascii: "="), UInt8(ascii: "/"), UInt8(ascii: "&"),
	                  UInt8(ascii: "\""), 0x00])
	func invalidXMLNameChar(_ b: UInt8) {
		#expect(!b.isXMLNameChar)
	}

	// MARK: - ArraySlice<UInt8>.equals

	@Test func equalsMatchingLiteral() {
		let bytes = ArraySlice("xmlns".utf8.map { UInt8($0) })
		#expect(bytes.equals("xmlns"))
	}

	@Test func equalsRejectsContentMismatch() {
		let bytes = ArraySlice("xmlns".utf8.map { UInt8($0) })
		#expect(!bytes.equals("XMLNS"))
		#expect(!bytes.equals("xmlnz"))
	}

	@Test func equalsRejectsLengthMismatch() {
		let bytes = ArraySlice("xml".utf8.map { UInt8($0) })
		#expect(!bytes.equals("xmlns"))
		#expect(!bytes.equals("xm"))
	}

	@Test func equalsEmptySlice() {
		let bytes = ArraySlice<UInt8>()
		#expect(bytes.equals(""))
		#expect(!bytes.equals("x"))
	}

	@Test func equalsUsesSliceStartIndex() {
		// Make sure we honor the slice bounds, not the underlying array.
		let full = Array("..xmlns..".utf8.map { UInt8($0) })
		let slice = full[2..<7] // "xmlns"
		#expect(slice.equals("xmlns"))
		#expect(!slice.equals("..xmlns.."))
	}

	// MARK: - ArraySlice<UInt8>.equalsASCIICaseInsensitive

	@Test func caseInsensitiveExactMatch() {
		let bytes = ArraySlice("xmlns".utf8.map { UInt8($0) })
		#expect(bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "xmlns"))
	}

	@Test func caseInsensitiveUppercaseMatches() {
		let bytes = ArraySlice("XMLNS".utf8.map { UInt8($0) })
		#expect(bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "xmlns"))
	}

	@Test func caseInsensitiveMixedCaseMatches() {
		let bytes = ArraySlice("XmLnS".utf8.map { UInt8($0) })
		#expect(bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "xmlns"))
	}

	@Test func caseInsensitiveRejectsContentMismatch() {
		let bytes = ArraySlice("xmlnz".utf8.map { UInt8($0) })
		#expect(!bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "xmlns"))
	}

	@Test func caseInsensitiveRejectsLengthMismatch() {
		let bytes = ArraySlice("xml".utf8.map { UInt8($0) })
		#expect(!bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "xmlns"))
	}

	@Test func caseInsensitivePreservesNonLetters() {
		// Hyphens and digits in the input should compare byte-for-byte —
		// the case-fold only affects letters.
		let bytes = ArraySlice("utf-8".utf8.map { UInt8($0) })
		#expect(bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "utf-8"))
		#expect(!bytes.equalsASCIICaseInsensitive(lowercaseLiteral: "utf_8"))
	}
}
