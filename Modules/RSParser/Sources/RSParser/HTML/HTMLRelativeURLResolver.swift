//
//  HTMLRelativeURLResolver.swift
//  RSParser
//
//  Created by Brent Simmons on 7/28/26.
//

import Foundation

/// Resolves relative URLs in HTML attribute values (href, src, poster, srcset)
/// against a base URL — used for Atom xml:base support.
///
/// Replacement is surgical: everything outside a rewritten attribute value is
/// byte-identical to the input. Values are left alone when they are empty,
/// fragment-only (`#…` — same-document references), or already have a scheme
/// (http:, data:, mailto:, and so on). Protocol-relative values (`//…`) do get
/// resolved, taking the base URL's scheme.
///
/// Attribute values are not entity-decoded — `URL(string:relativeTo:)` passes
/// characters like `&` through untouched, so an `&amp;` in a relative URL
/// survives resolution byte-for-byte.
public enum HTMLRelativeURLResolver {

	public static func resolvingRelativeURLs(in html: String, baseURL: URL) -> String {
		let bytes = Array(html.utf8)
		guard let rewritten = rewrittenBytes(bytes[...], baseURL: baseURL) else {
			return html
		}
		return String(decoding: rewritten, as: UTF8.self)
	}

	public static func resolvingRelativeURLs(inBytes bytes: ArraySlice<UInt8>, baseURL: URL) -> String {
		guard let rewritten = rewrittenBytes(bytes, baseURL: baseURL) else {
			return String(decoding: bytes, as: UTF8.self)
		}
		return String(decoding: rewritten, as: UTF8.self)
	}
}

// MARK: - Private

private extension HTMLRelativeURLResolver {

	/// Returns nil when nothing needs resolving, so callers can keep the input verbatim.
	static func rewrittenBytes(_ bytes: ArraySlice<UInt8>, baseURL: URL) -> [UInt8]? {
		var scanner = URLReplacementScanner(bytes: bytes, baseURL: baseURL)
		let replacements = scanner.scan()
		if replacements.isEmpty {
			return nil
		}

		let sizeDelta = replacements.reduce(0) { $0 + $1.bytes.count - $1.range.count }
		var result = [UInt8]()
		result.reserveCapacity(bytes.count + sizeDelta)

		var copyStart = bytes.startIndex
		for replacement in replacements {
			result.append(contentsOf: bytes[copyStart..<replacement.range.lowerBound])
			result.append(contentsOf: replacement.bytes)
			copyStart = replacement.range.upperBound
		}
		result.append(contentsOf: bytes[copyStart...])
		return result
	}

	struct Replacement {
		let range: Range<Int>
		let bytes: [UInt8]
	}

	/// Scans HTML bytes and collects the URL attribute-value replacements to make.
	struct URLReplacementScanner {

		private let bytes: ArraySlice<UInt8>
		private let baseURL: URL
		private var pos: Int
		private var replacements: [Replacement] = []

		private var end: Int {
			bytes.endIndex
		}

		init(bytes: ArraySlice<UInt8>, baseURL: URL) {
			self.bytes = bytes
			self.baseURL = baseURL
			self.pos = bytes.startIndex
		}

		mutating func scan() -> [Replacement] {
			while pos < end {
				if bytes[pos] == .asciiLessThan {
					handleLessThan()
				} else {
					pos += 1
				}
			}
			return replacements
		}

		// MARK: Markup dispatch

		private mutating func handleLessThan() {
			guard pos + 1 < end else {
				pos = end
				return
			}

			let next = bytes[pos + 1]
			if next == .asciiExclamation {
				handleDeclaration()
			} else if next == .asciiQuestion {
				skipPast("?>")
			} else if next == .asciiSlash {
				skipPastGreaterThan()
			} else if next.isASCIILetter {
				scanStartTag()
			} else {
				pos += 1
			}
		}

		private mutating func handleDeclaration() {
			if matches("<!--") {
				skipPast("-->")
			} else if matches("<![CDATA[") {
				skipPast("]]>")
			} else {
				skipPastGreaterThan()
			}
		}

		// MARK: Start tags

		private mutating func scanStartTag() {
			let nameStart = pos + 1
			var i = nameStart
			while i < end && bytes[i].isXMLNameChar {
				i += 1
			}
			let tagName = bytes[nameStart..<i]
			pos = i

			var selfClosing = false
			while pos < end {
				skipWhitespace()
				guard pos < end else {
					return
				}
				let b = bytes[pos]
				if b == .asciiGreaterThan {
					pos += 1
					break
				}
				if b == .asciiSlash {
					if pos + 1 < end && bytes[pos + 1] == .asciiGreaterThan {
						selfClosing = true
						pos += 2
						break
					}
					pos += 1
					continue
				}
				if b.isXMLNameStart {
					scanAttribute()
				} else {
					pos += 1
				}
			}

			// Nothing inside script or style elements is a URL to resolve.
			if !selfClosing {
				if tagName.equalsASCIICaseInsensitive(lowercaseLiteral: "script") {
					skipRawText(lowercaseCloseTagName: "script")
				} else if tagName.equalsASCIICaseInsensitive(lowercaseLiteral: "style") {
					skipRawText(lowercaseCloseTagName: "style")
				}
			}
		}

		private mutating func scanAttribute() {
			let nameStart = pos
			while pos < end {
				let b = bytes[pos]
				if b.isASCIIWhitespace || b == .asciiEquals || b == .asciiGreaterThan || b == .asciiSlash {
					break
				}
				pos += 1
			}
			let name = bytes[nameStart..<pos]

			skipWhitespace()
			guard pos < end, bytes[pos] == .asciiEquals else {
				return // valueless attribute
			}
			pos += 1
			skipWhitespace()
			guard pos < end else {
				return
			}

			let valueRange: Range<Int>
			let quote = bytes[pos]
			if quote == .asciiDoubleQuote || quote == .asciiSingleQuote {
				let valueStart = pos + 1
				var i = valueStart
				while i < end && bytes[i] != quote {
					i += 1
				}
				guard i < end else {
					// Unterminated quote — abandon the rest of the scan.
					// Replacements recorded so far were well-formed and stay.
					pos = end
					return
				}
				valueRange = valueStart..<i
				pos = i + 1
			} else {
				// Unquoted value: ends at whitespace or `>` (the WHATWG rule).
				// Deliberately not at `/`, so href=/foo/bar isn't truncated.
				let valueStart = pos
				var i = pos
				while i < end && !bytes[i].isASCIIWhitespace && bytes[i] != .asciiGreaterThan {
					i += 1
				}
				valueRange = valueStart..<i
				pos = i
			}

			handleAttributeValue(name: name, valueRange: valueRange)
		}

		private mutating func handleAttributeValue(name: ArraySlice<UInt8>, valueRange: Range<Int>) {
			if name.equalsASCIICaseInsensitive(lowercaseLiteral: "href") ||
				name.equalsASCIICaseInsensitive(lowercaseLiteral: "src") ||
				name.equalsASCIICaseInsensitive(lowercaseLiteral: "poster") {
				addReplacementIfNeeded(valueRange)
			} else if name.equalsASCIICaseInsensitive(lowercaseLiteral: "srcset") {
				handleSrcsetValue(valueRange)
			}
		}

		// MARK: srcset

		private mutating func handleSrcsetValue(_ valueRange: Range<Int>) {
			var i = valueRange.lowerBound
			let valueEnd = valueRange.upperBound

			while i < valueEnd {
				while i < valueEnd && (bytes[i].isASCIIWhitespace || bytes[i] == .asciiComma) {
					i += 1
				}
				guard i < valueEnd else {
					return
				}

				// URL token: up to whitespace. Trailing commas are separators, not URL.
				let urlStart = i
				while i < valueEnd && !bytes[i].isASCIIWhitespace {
					i += 1
				}
				var urlEnd = i
				while urlEnd > urlStart && bytes[urlEnd - 1] == .asciiComma {
					urlEnd -= 1
				}
				let tokenEndedWithComma = urlEnd < i

				if urlEnd > urlStart {
					addReplacementIfNeeded(urlStart..<urlEnd)
				}

				// A trailing comma already ended this candidate. Otherwise skip
				// the descriptor — everything up to the next comma.
				if !tokenEndedWithComma {
					while i < valueEnd && bytes[i] != .asciiComma {
						i += 1
					}
				}
			}
		}

		// MARK: URL classification and resolution

		private mutating func addReplacementIfNeeded(_ range: Range<Int>) {
			// Browsers strip surrounding whitespace before processing a URL value.
			// Classify and replace only the trimmed part — the whitespace stays.
			let trimmed = trimmingASCIIWhitespace(range)
			guard let resolved = resolvedURLBytes(bytes[trimmed]) else {
				return
			}
			replacements.append(Replacement(range: trimmed, bytes: resolved))
		}

		private func trimmingASCIIWhitespace(_ range: Range<Int>) -> Range<Int> {
			var lower = range.lowerBound
			var upper = range.upperBound
			while lower < upper && bytes[lower].isASCIIWhitespace {
				lower += 1
			}
			while upper > lower && bytes[upper - 1].isASCIIWhitespace {
				upper -= 1
			}
			return lower..<upper
		}

		private func resolvedURLBytes(_ value: ArraySlice<UInt8>) -> [UInt8]? {
			guard shouldResolve(value) else {
				return nil
			}
			let s = String(decoding: value, as: UTF8.self)
			guard let resolved = URL(string: s, relativeTo: baseURL)?.absoluteString, resolved != s else {
				return nil
			}
			return Array(resolved.utf8)
		}

		private func shouldResolve(_ value: ArraySlice<UInt8>) -> Bool {
			guard let first = value.first else {
				return false // empty
			}
			if first == .asciiHash {
				return false // same-document reference
			}
			return !hasScheme(value)
		}

		/// True when the value starts with a URL scheme (`[A-Za-z][A-Za-z0-9+.-]*:`).
		private func hasScheme(_ value: ArraySlice<UInt8>) -> Bool {
			guard let first = value.first, first.isASCIILetter else {
				return false
			}
			var i = value.startIndex + 1
			while i < value.endIndex {
				let b = value[i]
				if b == .asciiColon {
					return true
				}
				if !(b.isASCIILetter || b.isASCIIDigit || b == .asciiPlus || b == .asciiHyphen || b == .asciiDot) {
					return false
				}
				i += 1
			}
			return false
		}

		// MARK: Scanning helpers

		private mutating func skipWhitespace() {
			while pos < end && bytes[pos].isASCIIWhitespace {
				pos += 1
			}
		}

		private mutating func skipPastGreaterThan() {
			while pos < end && bytes[pos] != .asciiGreaterThan {
				pos += 1
			}
			if pos < end {
				pos += 1
			}
		}

		private func matches(_ literal: StaticString) -> Bool {
			let count = literal.utf8CodeUnitCount
			guard pos + count <= end else {
				return false
			}
			return bytes[pos..<pos + count].equals(literal)
		}

		private mutating func skipPast(_ literal: StaticString) {
			let count = literal.utf8CodeUnitCount
			while pos + count <= end {
				if bytes[pos..<pos + count].equals(literal) {
					pos += count
					return
				}
				pos += 1
			}
			pos = end
		}

		private mutating func skipRawText(lowercaseCloseTagName: StaticString) {
			let nameCount = lowercaseCloseTagName.utf8CodeUnitCount
			while pos < end {
				if bytes[pos] == .asciiLessThan && pos + 1 < end && bytes[pos + 1] == .asciiSlash {
					let nameStart = pos + 2
					let nameEnd = nameStart + nameCount
					if nameEnd <= end && bytes[nameStart..<nameEnd].equalsASCIICaseInsensitive(lowercaseLiteral: lowercaseCloseTagName)
						&& isCloseTagNameBoundary(at: nameEnd) {
						pos = nameEnd
						skipPastGreaterThan()
						return
					}
				}
				pos += 1
			}
		}

		// Keeps </scripty> from being mistaken for </script>.
		private func isCloseTagNameBoundary(at index: Int) -> Bool {
			guard index < end else {
				return true
			}
			let b = bytes[index]
			return b == .asciiGreaterThan || b == .asciiSlash || b.isASCIIWhitespace
		}
	}
}
