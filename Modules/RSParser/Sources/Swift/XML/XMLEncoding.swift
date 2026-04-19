//
//  XMLEncoding.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

// Detect the input's encoding and transcode to UTF-8 so the rest of the
// parser can scan a single code path.
//
// Detection order:
//   1. BOM
//   2. `<?xml ... encoding="..."?>` declaration (read as ASCII)
//   3. Default UTF-8

enum XMLEncoding {

	/// Return a UTF-8 byte array for `input`, transcoding if necessary.
	/// If the declared/sniffed encoding isn't supported, returns the input
	/// bytes unchanged (best-effort, liberal).
	static func toUTF8(_ input: [UInt8]) -> [UInt8] {
		let count = input.count

		// BOM-based detection first, since it's unambiguous.
		if hasUTF8BOM(input, count: count) {
			// Strip the BOM so the parser doesn't trip on it as content.
			return Array(input.dropFirst(3))
		}
		if hasUTF16LEBOM(input, count: count) {
			return transcode(input.dropFirst(2), encoding: .utf16LittleEndian) ?? input
		}
		if hasUTF16BEBOM(input, count: count) {
			return transcode(input.dropFirst(2), encoding: .utf16BigEndian) ?? input
		}

		// No BOM — look at the XML declaration for an `encoding` attribute.
		guard let encoding = detectEncodingFromDeclaration(input, count: count) else {
			return input
		}

		switch encoding {
		case .utf8:
			return input
		case .latin1:
			return transcodeLatin1(input, count: count)
		case .windows1252:
			return transcodeWindows1252(input, count: count)
		case .foundation(let swiftEncoding):
			return transcode(input[...], encoding: swiftEncoding) ?? input
		}
	}

	/// What `matchEncodingName` resolved the declaration's encoding name to.
	private enum DetectedEncoding {
		/// Pass-through: input is already UTF-8 (or ASCII, which is a UTF-8 subset).
		case utf8
		/// Hand-rolled fast path for ISO-8859-1 — bytes map 1:1 to codepoints.
		case latin1
		/// Hand-rolled fast path for Windows-1252 — same as Latin-1 except 0x80–0x9F.
		case windows1252
		/// Anything else — delegate to Foundation's `String(data:encoding:)`.
		case foundation(String.Encoding)
	}

	/// Encoding names that Foundation's `String(data:encoding:)` can decode for us.
	/// Keys are lowercase, since the caller lowercases before lookup. Values marked
	/// `cf(...)` come from the `CFStringEncodings` enum and are bridged via
	/// `CFStringConvertEncodingToNSStringEncoding` — Swift's `String.Encoding`
	/// directly exposes only a subset of what Foundation can actually decode.
	private static let foundationEncodings: [String: String.Encoding] = [
		// UTF-16 variants. "utf-16" without BOM defaults to BE per spec.
		"utf-16": .utf16BigEndian,
		"utf16": .utf16BigEndian,
		"utf-16be": .utf16BigEndian,
		"utf-16le": .utf16LittleEndian,

		// Other Latin / European
		"iso-8859-2": .isoLatin2,
		"latin2": .isoLatin2,
		"iso-8859-5": cf(.isoLatinCyrillic),
		"iso-8859-9": cf(.isoLatin5),           // Turkish
		"iso-8859-15": cf(.isoLatin9),          // Euro

		// Cyrillic
		"windows-1251": .windowsCP1251,
		"cp1251": .windowsCP1251,
		"koi8-r": cf(.KOI8_R),

		// Japanese
		"shift_jis": .shiftJIS,
		"shift-jis": .shiftJIS,
		"sjis": .shiftJIS,
		"euc-jp": .japaneseEUC,
		"iso-2022-jp": .iso2022JP,

		// Simplified Chinese
		"gb2312": cf(.GB_2312_80),
		"gbk": cf(.GBK_95),
		"gb18030": cf(.GB_18030_2000),

		// Traditional Chinese
		"big5": cf(.big5),

		// Korean
		"euc-kr": cf(.EUC_KR),

		// Other Windows code pages occasionally seen in European feeds
		"windows-1250": .windowsCP1250,         // Central/Eastern European
		"cp1250": .windowsCP1250,
		"windows-1253": .windowsCP1253,         // Greek
		"cp1253": .windowsCP1253,
		"windows-1254": .windowsCP1254,         // Turkish
		"cp1254": .windowsCP1254
	]
}

private extension XMLEncoding {

	// MARK: - BOM

	private static func hasUTF8BOM(_ input: [UInt8], count: Int) -> Bool {
		count >= 3 && input[0] == 0xEF && input[1] == 0xBB && input[2] == 0xBF
	}

	private static func hasUTF16LEBOM(_ input: [UInt8], count: Int) -> Bool {
		count >= 2 && input[0] == 0xFF && input[1] == 0xFE
	}

	private static func hasUTF16BEBOM(_ input: [UInt8], count: Int) -> Bool {
		count >= 2 && input[0] == 0xFE && input[1] == 0xFF
	}

	// MARK: - XML declaration

	/// Scan the first ~200 bytes as ASCII, looking for an `encoding="..."` value in
	/// the XML declaration. Returns nil if there's no declaration, no encoding
	/// attribute, or an unknown encoding name.
	private static func detectEncodingFromDeclaration(_ input: [UInt8], count: Int) -> DetectedEncoding? {
		let limit = Swift.min(count, 200)
		var i = 0
		while i < limit && input[i].isASCIIWhitespace {
			i += 1
		}
		// Must start with `<?xml`.
		guard matchLiteral(input, from: i, limit: limit, literal: "<?xml") else {
			return nil
		}

		let declEnd = findXMLDeclEnd(input, start: i, limit: limit) ?? limit
		guard let encodingStart = findSubsequenceCaseInsensitive(input, key: "encoding", start: i, end: declEnd) else {
			return nil
		}

		var j = encodingStart + "encoding".utf8.count
		while j < declEnd && input[j].isASCIIWhitespace {
			j += 1
		}
		guard j < declEnd && input[j] == .asciiEquals else {
			return nil
		}
		j += 1
		while j < declEnd && input[j].isASCIIWhitespace {
			j += 1
		}
		guard j < declEnd else {
			return nil
		}
		let quote = input[j]
		guard quote == .asciiDoubleQuote || quote == .asciiSingleQuote else {
			return nil
		}
		j += 1
		let valueStart = j
		while j < declEnd && input[j] != quote {
			j += 1
		}
		guard j < declEnd else {
			return nil
		}
		return matchEncodingName(input[valueStart..<j])
	}

	private static func findXMLDeclEnd(_ input: [UInt8], start: Int, limit: Int) -> Int? {
		var k = start
		while k + 1 < limit {
			if input[k] == .asciiQuestion && input[k + 1] == .asciiGreaterThan {
				return k
			}
			k += 1
		}
		return nil
	}

	/// Match `input[from...]` against a short ASCII literal, case-sensitive.
	private static func matchLiteral(_ input: [UInt8], from: Int, limit: Int, literal: StaticString) -> Bool {
		let count = literal.utf8CodeUnitCount
		guard limit - from >= count else {
			return false
		}
		return literal.withUTF8Buffer { lit -> Bool in
			for k in 0..<count where input[from + k] != lit[k] {
				return false
			}
			return true
		}
	}

	/// Search `input[start..<end]` for `key` (ASCII literal), case-insensitive.
	/// Returns the starting index of the match, or nil.
	private static func findSubsequenceCaseInsensitive(_ input: [UInt8], key: StaticString, start: Int, end: Int) -> Int? {
		let keyCount = key.utf8CodeUnitCount
		guard keyCount > 0, end - start >= keyCount else {
			return nil
		}
		return key.withUTF8Buffer { lit -> Int? in
			var i = start
			while i <= end - keyCount {
				var match = true
				for k in 0..<keyCount where input[i + k].asciiLowercased != lit[k] {
					match = false
					break
				}
				if match {
					return i
				}
				i += 1
			}
			return nil
		}
	}

	// MARK: - Encoding name → behavior

	/// Map an encoding name (case-insensitive) to a transcoding strategy. Covers
	/// the feed-relevant encodings: UTF-8/16, Latin-1, Windows-1252, common Latin
	/// variants, Cyrillic, and the major CJK encodings. Unknown names return nil.
	private static func matchEncodingName(_ value: ArraySlice<UInt8>) -> DetectedEncoding? {
		// Fast paths for the ones we hand-roll or handle via Foundation UTF-16.
		if value.equalsASCIICaseInsensitive(lowercaseLiteral: "utf-8") ||
			value.equalsASCIICaseInsensitive(lowercaseLiteral: "utf8") ||
			value.equalsASCIICaseInsensitive(lowercaseLiteral: "us-ascii") ||
			value.equalsASCIICaseInsensitive(lowercaseLiteral: "ascii") {
			return .utf8
		}
		if value.equalsASCIICaseInsensitive(lowercaseLiteral: "iso-8859-1") ||
			value.equalsASCIICaseInsensitive(lowercaseLiteral: "latin1") ||
			value.equalsASCIICaseInsensitive(lowercaseLiteral: "latin-1") {
			return .latin1
		}
		if value.equalsASCIICaseInsensitive(lowercaseLiteral: "windows-1252") ||
			value.equalsASCIICaseInsensitive(lowercaseLiteral: "cp1252") {
			return .windows1252
		}

		// Foundation handles the rest. Walk a small table of (name → encoding).
		let asciiName = String(decoding: value, as: UTF8.self).lowercased()
		if let encoding = foundationEncodings[asciiName] {
			return .foundation(encoding)
		}
		return nil
	}

	static func cf(_ encoding: CFStringEncodings) -> String.Encoding {
		String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
	}

	// MARK: - Transcoding

	/// Foundation-based transcode: bytes → String → UTF-8 bytes.
	static func transcode(_ slice: ArraySlice<UInt8>, encoding: String.Encoding) -> [UInt8]? {
		let data = Data(slice)
		guard let str = String(data: data, encoding: encoding) else {
			return nil
		}
		return Array(str.utf8)
	}

	/// ISO-8859-1: byte value == codepoint. Inline to UTF-8.
	static func transcodeLatin1(_ input: [UInt8], count: Int) -> [UInt8] {
		var out = [UInt8]()
		out.reserveCapacity(count)
		for b in input {
			if b < 0x80 {
				out.append(b)
			} else {
				// 2-byte UTF-8.
				out.append(0xC0 | (b >> 6))
				out.append(0x80 | (b & 0x3F))
			}
		}
		return out
	}

	/// Windows-1252: like Latin-1 except bytes 0x80–0x9F map to specific codepoints.
	/// Inlines the UTF-8 encoding for those codepoints — no per-byte allocation.
	static func transcodeWindows1252(_ input: [UInt8], count: Int) -> [UInt8] {
		var out = [UInt8]()
		out.reserveCapacity(count)
		for b in input {
			if b < 0x80 {
				out.append(b)
				continue
			}
			if b >= 0x80 && b <= 0x9F {
				let cp = XMLEntities.windowsLatin1Extension[Int(b - 0x80)]
				// Inline UTF-8 encoding — all codepoints in the table fit in ≤ 3 bytes.
				if cp < 0x80 {
					out.append(UInt8(cp))
				} else if cp < 0x800 {
					out.append(UInt8(0xC0 | (cp >> 6)))
					out.append(UInt8(0x80 | (cp & 0x3F)))
				} else {
					out.append(UInt8(0xE0 | (cp >> 12)))
					out.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
					out.append(UInt8(0x80 | (cp & 0x3F)))
				}
			} else {
				// 0xA0–0xFF — same as Latin-1.
				out.append(0xC0 | (b >> 6))
				out.append(0x80 | (b & 0x3F))
			}
		}
		return out
	}
}
