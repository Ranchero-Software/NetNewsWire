//
//  XMLEncodingTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//
//  Direct unit tests for `XMLEncoding.toUTF8`. Covers BOMs, declaration-based
//  detection, encoding-name aliases and case-insensitivity, the hand-rolled
//  Latin-1/Windows-1252 paths, the Foundation-bridged CJK/Cyrillic paths, and
//  boundary inputs.

import Foundation
import Testing
@testable import RSParser

@Suite struct XMLEncodingTests {

	// MARK: - Helpers

	private func decl(_ encodingName: String, singleQuoted: Bool = false) -> [UInt8] {
		let q = singleQuoted ? "'" : "\""
		return Array("<?xml version=\(q)1.0\(q) encoding=\(q)\(encodingName)\(q)?>".utf8)
	}

	private static func cfEnc(_ cf: CFStringEncodings) -> String.Encoding {
		String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cf.rawValue)))
	}

	/// Build a declaration + `<a>…</a>` body from encoded content bytes, run it
	/// through `XMLEncoding.toUTF8`, and assert the result (as UTF-8 string)
	/// contains the expected text wrapped in `<a>…</a>`.
	private func assertRoundTrip(text: String,
	                             via encoding: String.Encoding,
	                             declaredAs name: String,
	                             sourceLocation: SourceLocation = #_sourceLocation) {
		guard let encoded = text.data(using: encoding) else {
			Issue.record("Foundation couldn't encode \(text.debugDescription) as \(encoding)", sourceLocation: sourceLocation)
			return
		}
		let input = decl(name) + Array("<a>".utf8) + Array(encoded) + Array("</a>".utf8)
		let result = XMLEncoding.toUTF8(input)
		let resultString = String(decoding: result, as: UTF8.self)
		#expect(resultString.contains("<a>\(text)</a>"),
		        "failed for \(name): got \(resultString.debugDescription)",
		        sourceLocation: sourceLocation)
	}

	// MARK: - Pass-through and boundary conditions

	@Test func plainUTF8NoDeclarationReturnsInputUnchanged() {
		let input: [UInt8] = Array("<root>hello</root>".utf8)
		#expect(XMLEncoding.toUTF8(input) == input)
	}

	@Test func emptyInputReturnsEmpty() {
		#expect(XMLEncoding.toUTF8([]) == [])
	}

	@Test func oneByteInputReturnsUnchanged() {
		#expect(XMLEncoding.toUTF8([0x58]) == [0x58])
	}

	@Test func twoByteInputReturnsUnchanged() {
		#expect(XMLEncoding.toUTF8([0x58, 0x59]) == [0x58, 0x59])
	}

	// MARK: - BOMs

	@Test func utf8BOMStripped() {
		let input: [UInt8] = [0xEF, 0xBB, 0xBF] + Array("<a/>".utf8)
		#expect(XMLEncoding.toUTF8(input) == Array("<a/>".utf8))
	}

	@Test func utf16LEBOMDecoded() {
		var bytes: [UInt8] = [0xFF, 0xFE]
		for scalar in "<a>é</a>".unicodeScalars {
			let v = UInt16(scalar.value)
			bytes.append(UInt8(v & 0xFF))
			bytes.append(UInt8(v >> 8))
		}
		let result = XMLEncoding.toUTF8(bytes)
		#expect(String(decoding: result, as: UTF8.self) == "<a>é</a>")
	}

	@Test func utf16BEBOMDecoded() {
		var bytes: [UInt8] = [0xFE, 0xFF]
		for scalar in "<a>é</a>".unicodeScalars {
			let v = UInt16(scalar.value)
			bytes.append(UInt8(v >> 8))
			bytes.append(UInt8(v & 0xFF))
		}
		let result = XMLEncoding.toUTF8(bytes)
		#expect(String(decoding: result, as: UTF8.self) == "<a>é</a>")
	}

	// MARK: - Name matching: case insensitivity and aliases

	@Test("ISO-8859-1 is recognized regardless of case",
	      arguments: ["ISO-8859-1", "iso-8859-1", "Iso-8859-1", "iSO-8859-1"])
	func encodingNameIsCaseInsensitive(_ name: String) {
		let tail: [UInt8] = Array("<a>".utf8) + [0xE9] + Array("</a>".utf8) // 0xE9 = é in Latin-1
		let input = decl(name) + tail
		let result = XMLEncoding.toUTF8(input)
		#expect(String(decoding: result, as: UTF8.self).contains("<a>é</a>"))
	}

	@Test("UTF-8 and US-ASCII aliases pass input through unchanged",
	      arguments: ["UTF-8", "utf-8", "utf8", "UTF8", "us-ascii", "ASCII"])
	func utf8Alias(_ name: String) {
		let tail = Array("<a>hello</a>".utf8)
		let input = decl(name) + tail
		#expect(XMLEncoding.toUTF8(input) == input)
	}

	@Test("Latin-1 aliases all decode the same bytes",
	      arguments: ["ISO-8859-1", "latin1", "latin-1", "LATIN-1"])
	func latin1Alias(_ name: String) {
		let tail: [UInt8] = Array("<a>".utf8) + [0xE9] + Array("</a>".utf8)
		let input = decl(name) + tail
		let result = XMLEncoding.toUTF8(input)
		#expect(String(decoding: result, as: UTF8.self).contains("<a>é</a>"))
	}

	@Test("Windows-1252 aliases all decode smart-quote bytes",
	      arguments: ["windows-1252", "Windows-1252", "cp1252", "CP1252"])
	func windows1252Alias(_ name: String) {
		// 0x93 / 0x94 are left/right curly double quotes in Windows-1252.
		let tail: [UInt8] = Array("<a>".utf8) + [0x93] + Array("Hi".utf8) + [0x94] + Array("</a>".utf8)
		let input = decl(name) + tail
		let result = XMLEncoding.toUTF8(input)
		#expect(String(decoding: result, as: UTF8.self).contains("<a>\u{201C}Hi\u{201D}</a>"))
	}

	// MARK: - Unknown / missing / quirky declarations

	@Test func unknownEncodingFallsThroughUnchanged() {
		let input = Array("<?xml version=\"1.0\" encoding=\"xyz-9000\"?><root>hello</root>".utf8)
		#expect(XMLEncoding.toUTF8(input) == input)
	}

	@Test func singleQuotedEncodingAttribute() {
		let tail: [UInt8] = Array("<a>".utf8) + [0xE9] + Array("</a>".utf8)
		let input = decl("ISO-8859-1", singleQuoted: true) + tail
		let result = XMLEncoding.toUTF8(input)
		#expect(String(decoding: result, as: UTF8.self).contains("<a>é</a>"))
	}

	@Test func leadingWhitespaceBeforeDeclaration() {
		let tail: [UInt8] = Array("<a>".utf8) + [0xE9] + Array("</a>".utf8)
		let input = Array("  \n\t".utf8) + decl("ISO-8859-1") + tail
		let result = XMLEncoding.toUTF8(input)
		#expect(String(decoding: result, as: UTF8.self).contains("<a>é</a>"))
	}

	@Test func declarationWithoutEncodingAttribute() {
		// Just `version`, no `encoding` — should fall through to UTF-8 pass-through.
		let input = Array("<?xml version=\"1.0\"?><root>hello</root>".utf8)
		#expect(XMLEncoding.toUTF8(input) == input)
	}

	// MARK: - Foundation-bridged CJK / Cyrillic / European

	@Test func shiftJIS() {
		assertRoundTrip(text: "日本語", via: .shiftJIS, declaredAs: "shift_jis")
	}

	@Test func shiftJISAlternateName() {
		assertRoundTrip(text: "日本語", via: .shiftJIS, declaredAs: "Shift-JIS")
	}

	@Test func eucJP() {
		assertRoundTrip(text: "日本語", via: .japaneseEUC, declaredAs: "euc-jp")
	}

	@Test func windows1251Cyrillic() {
		assertRoundTrip(text: "Русский", via: .windowsCP1251, declaredAs: "windows-1251")
	}

	@Test func isoLatin2CentralEuropean() {
		assertRoundTrip(text: "Český", via: .isoLatin2, declaredAs: "iso-8859-2")
	}

	@Test func isoLatin9Euro() {
		assertRoundTrip(text: "€100", via: Self.cfEnc(.isoLatin9), declaredAs: "iso-8859-15")
	}

	@Test func big5TraditionalChinese() {
		assertRoundTrip(text: "繁體中文", via: Self.cfEnc(.big5), declaredAs: "big5")
	}

	@Test func eucKRKorean() {
		assertRoundTrip(text: "한국어", via: Self.cfEnc(.EUC_KR), declaredAs: "euc-kr")
	}

	@Test func koi8RCyrillic() {
		assertRoundTrip(text: "Русский", via: Self.cfEnc(.KOI8_R), declaredAs: "koi8-r")
	}

	@Test func gbkSimplifiedChinese() {
		// GB2312 is a narrower charset that Foundation won't let us encode arbitrary
		// Chinese into; it's covered end-to-end by RSSParserTests.feedWithGB2312Encoding.
		// Here we cover the broader GBK path.
		assertRoundTrip(text: "简体中文", via: Self.cfEnc(.GBK_95), declaredAs: "gbk")
	}
}
