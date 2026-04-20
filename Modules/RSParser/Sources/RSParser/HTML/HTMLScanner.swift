//
//  HTMLScanner.swift
//  RSParser
//
//  Created by Brent Simmons on 4/19/26.
//

// Liberal, byte-oriented HTML scanner with a SAX-style delegate.
//
// Byte slices throughout. Entity references (named, decimal, hex) are expanded
// via `XMLEntities.decode`. Comments, DOCTYPE, and PIs are silently consumed.
//
// Differs from the XML scanner in ways HTML requires:
//   - Tag names compared case-insensitively (but emitted as they appear).
//   - Content of `<script>` and `<style>` treated as opaque raw text: only
//     the matching `</script>` / `</style>` ends the block.
//   - Attributes may have no value (`<input disabled>`), single-quoted values,
//     or unquoted values (`<a href=foo>`).
//   - No void-element tracking. Consumers that care (both of ours don't)
//     apply their own void-element list at the delegate level.
//
// Not re-entrant. Callbacks happen on the thread that called `parse(_:)`.

public final class HTMLScanner {

	public weak var delegate: HTMLScannerDelegate?

	public init(delegate: HTMLScannerDelegate) {
		self.delegate = delegate
	}

	public func parse(_ bytes: [UInt8]) {
		self.input = bytes
		self.pos = 0
		drive()
		delegate?.htmlScannerDidEnd(self)
	}

	// MARK: - Private state

	private var input: [UInt8] = []
	private var pos: Int = 0
}

// MARK: - Private

private extension HTMLScanner {

	// Tag names that enter raw-text mode. Their content isn't parsed as markup;
	// only the matching </script> or </style> ends the block.
	static let scriptBytes: [UInt8] = Array("script".utf8)
	static let styleBytes: [UInt8] = Array("style".utf8)

	func drive() {
		while pos < input.count {
			let b = input[pos]
			if b == .asciiLessThan {
				scanMarkup()
			} else {
				scanCharacters()
			}
		}
	}

	// MARK: - Markup dispatch

	/// Handle everything starting with `<`. Consumes silent markup in place,
	/// emits delegate callbacks for tags and character content.
	func scanMarkup() {
		assert(input[pos] == .asciiLessThan)
		let next = peek(1)

		if next == .asciiExclamation {
			if matchPrefix("<!--") {
				consumeComment()
				return
			}
			if matchPrefix("<![CDATA[") {
				consumeCDATA()
				return
			}
			// Both <!DOCTYPE and <!anything-else — skip to `>`.
			consumeUnknownDeclaration()
			return
		}

		if next == .asciiQuestion {
			consumeProcessingInstruction()
			return
		}

		if next == .asciiSlash {
			scanEndTag()
			return
		}

		if next?.isXMLNameStart == true {
			scanStartTag()
			return
		}

		// Stray `<` — emit it as literal text and advance.
		delegate?.htmlScanner(self, didFindCharacters: [.asciiLessThan][...])
		pos += 1
	}

	// MARK: - Start tag

	func scanStartTag() {
		assert(input[pos] == .asciiLessThan)
		pos += 1

		let nameRange = scanTagName()
		let nameSlice = input[nameRange]

		var attributes: [(name: ArraySlice<UInt8>, value: String)] = []
		var selfClosing = false

		while pos < input.count {
			skipWhitespace()
			if pos >= input.count {
				break
			}
			let b = input[pos]
			if b == .asciiGreaterThan {
				pos += 1
				break
			}
			if b == .asciiSlash {
				if peek(1) == .asciiGreaterThan {
					selfClosing = true
					pos += 2
					break
				}
				pos += 1
				continue
			}
			if !b.isXMLNameStart {
				// Unrecognized garbage — advance and try again (liberal).
				pos += 1
				continue
			}
			if let attribute = scanAttribute() {
				attributes.append(attribute)
			}
		}

		let attributeView = HTMLAttributes(attributes: attributes)
		delegate?.htmlScanner(self, didStartTag: nameSlice, attributes: attributeView, selfClosing: selfClosing)

		// Raw-text mode for <script> and <style>.
		if !selfClosing {
			if tagNameEqualsIgnoringCase(nameSlice, Self.scriptBytes[...]) {
				consumeRawText(until: Self.scriptBytes[...])
			} else if tagNameEqualsIgnoringCase(nameSlice, Self.styleBytes[...]) {
				consumeRawText(until: Self.styleBytes[...])
			}
		}
	}

	func scanAttribute() -> (name: ArraySlice<UInt8>, value: String)? {
		let nameRange = scanAttributeName()
		if nameRange.isEmpty {
			return nil
		}
		let nameSlice = input[nameRange]

		skipWhitespace()
		// No value (e.g. `<input disabled>`): empty string value.
		guard pos < input.count, input[pos] == .asciiEquals else {
			return (name: nameSlice, value: "")
		}
		pos += 1
		skipWhitespace()
		guard pos < input.count else {
			return (name: nameSlice, value: "")
		}
		let value = scanAttributeValue()
		return (name: nameSlice, value: value)
	}

	func scanAttributeValue() -> String {
		let quote = input[pos]
		if quote == .asciiDoubleQuote || quote == .asciiSingleQuote {
			pos += 1
			let start = pos
			var out = [UInt8]()
			var expanded = false
			while pos < input.count {
				let b = input[pos]
				if b == quote {
					if !expanded {
						let s = String(decoding: input[start..<pos], as: UTF8.self)
						pos += 1
						return s
					}
					pos += 1
					return String(decoding: out, as: UTF8.self)
				}
				if b == .asciiAmpersand {
					if !expanded {
						out.reserveCapacity(32)
						out.append(contentsOf: input[start..<pos])
						expanded = true
					}
					let result = XMLEntities.decode(bytes: input, at: pos, mode: .html)
					out.append(contentsOf: result.bytes)
					pos = result.nextIndex
					continue
				}
				if expanded {
					out.append(b)
				}
				pos += 1
			}
			// EOF before closing quote (liberal).
			if !expanded {
				return String(decoding: input[start..<pos], as: UTF8.self)
			}
			return String(decoding: out, as: UTF8.self)
		}

		// Unquoted — consume until whitespace, `>`, or `/`.
		let start = pos
		var out = [UInt8]()
		var expanded = false
		while pos < input.count {
			let b = input[pos]
			if b.isASCIIWhitespace || b == .asciiGreaterThan || b == .asciiSlash {
				break
			}
			if b == .asciiAmpersand {
				if !expanded {
					out.append(contentsOf: input[start..<pos])
					expanded = true
				}
				let result = XMLEntities.decode(bytes: input, at: pos, mode: .html)
				out.append(contentsOf: result.bytes)
				pos = result.nextIndex
				continue
			}
			if expanded {
				out.append(b)
			}
			pos += 1
		}
		if !expanded {
			return String(decoding: input[start..<pos], as: UTF8.self)
		}
		return String(decoding: out, as: UTF8.self)
	}

	// MARK: - End tag

	func scanEndTag() {
		assert(input[pos] == .asciiLessThan && peek(1) == .asciiSlash)
		pos += 2

		let nameRange = scanTagName()
		let nameSlice = input[nameRange]

		// Skip any whitespace/garbage up to `>`.
		while pos < input.count && input[pos] != .asciiGreaterThan {
			pos += 1
		}
		if pos < input.count {
			pos += 1
		}

		delegate?.htmlScanner(self, didEndTag: nameSlice)
	}

	// MARK: - Script / style raw text

	/// In raw-text mode after a `<script>` or `<style>` start tag, scan forward
	/// until the matching end tag `</name>` (case-insensitive) and emit the
	/// accumulated bytes as characters, followed by the end tag.
	func consumeRawText(until tagName: ArraySlice<UInt8>) {
		let start = pos
		while pos < input.count {
			if input[pos] == .asciiLessThan && peek(1) == .asciiSlash {
				let savedPos = pos
				let closerStart = pos + 2
				var nameEnd = closerStart
				while nameEnd < input.count && input[nameEnd].isXMLNameChar {
					nameEnd += 1
				}
				let candidateName = input[closerStart..<nameEnd]
				if tagNameEqualsIgnoringCase(candidateName, tagName) {
					if start < savedPos {
						delegate?.htmlScanner(self, didFindCharacters: input[start..<savedPos])
					}
					pos = nameEnd
					while pos < input.count && input[pos] != .asciiGreaterThan {
						pos += 1
					}
					if pos < input.count {
						pos += 1
					}
					delegate?.htmlScanner(self, didEndTag: candidateName)
					return
				}
			}
			pos += 1
		}
		// EOF without closer — flush what we have as characters.
		if start < pos {
			delegate?.htmlScanner(self, didFindCharacters: input[start..<pos])
		}
	}

	// MARK: - Character data

	func scanCharacters() {
		let start = pos
		var out = [UInt8]()
		var sawEntity = false

		while pos < input.count {
			let b = input[pos]
			if b == .asciiLessThan {
				break
			}
			if b == .asciiAmpersand {
				if !sawEntity {
					out.reserveCapacity(input.count - start)
					out.append(contentsOf: input[start..<pos])
					sawEntity = true
				}
				let result = XMLEntities.decode(bytes: input, at: pos, mode: .html)
				out.append(contentsOf: result.bytes)
				pos = result.nextIndex
				continue
			}
			if sawEntity {
				out.append(b)
			}
			pos += 1
		}

		if !sawEntity {
			if start < pos {
				delegate?.htmlScanner(self, didFindCharacters: input[start..<pos])
			}
			return
		}
		delegate?.htmlScanner(self, didFindCharacters: out[...])
	}

	// MARK: - Consumption of non-emitting markup

	func consumeComment() {
		pos += 4 // `<!--`
		while pos + 2 < input.count {
			if input[pos] == .asciiHyphen
				&& input[pos + 1] == .asciiHyphen
				&& input[pos + 2] == .asciiGreaterThan {
				pos += 3
				return
			}
			pos += 1
		}
		pos = input.count
	}

	func consumeCDATA() {
		pos += 9 // `<![CDATA[`
		let start = pos
		var end = pos
		while end + 2 < input.count {
			if input[end] == .asciiRightBracket
				&& input[end + 1] == .asciiRightBracket
				&& input[end + 2] == .asciiGreaterThan {
				break
			}
			end += 1
		}
		if end + 2 >= input.count {
			end = input.count
			pos = end
		} else {
			pos = end + 3
		}
		if start < end {
			delegate?.htmlScanner(self, didFindCharacters: input[start..<end])
		}
	}

	func consumeProcessingInstruction() {
		pos += 2 // `<?`
		while pos + 1 < input.count {
			if input[pos] == .asciiQuestion && input[pos + 1] == .asciiGreaterThan {
				pos += 2
				return
			}
			pos += 1
		}
		pos = input.count
	}

	func consumeUnknownDeclaration() {
		while pos < input.count {
			if input[pos] == .asciiGreaterThan {
				pos += 1
				return
			}
			pos += 1
		}
	}

	// MARK: - Name scanning

	func scanTagName() -> Range<Int> {
		let start = pos
		while pos < input.count && input[pos].isXMLNameChar {
			pos += 1
		}
		return start..<pos
	}

	func scanAttributeName() -> Range<Int> {
		let start = pos
		while pos < input.count {
			let b = input[pos]
			if b.isASCIIWhitespace || b == .asciiEquals || b == .asciiGreaterThan || b == .asciiSlash {
				break
			}
			pos += 1
		}
		return start..<pos
	}

	// MARK: - Utilities

	func peek(_ offset: Int) -> UInt8? {
		let i = pos + offset
		guard i < input.count else {
			return nil
		}
		return input[i]
	}

	func skipWhitespace() {
		while pos < input.count && input[pos].isASCIIWhitespace {
			pos += 1
		}
	}

	func matchPrefix(_ literal: StaticString) -> Bool {
		let count = literal.utf8CodeUnitCount
		if pos + count > input.count {
			return false
		}
		return literal.withUTF8Buffer { ptr in
			for i in 0..<count {
				if input[pos + i] != ptr[i] {
					return false
				}
			}
			return true
		}
	}

	func tagNameEqualsIgnoringCase(_ a: ArraySlice<UInt8>, _ b: ArraySlice<UInt8>) -> Bool {
		guard a.count == b.count else {
			return false
		}
		for (ai, bi) in zip(a, b) {
			if ai.asciiLowercased != bi.asciiLowercased {
				return false
			}
		}
		return true
	}
}

// MARK: - Delegate

public protocol HTMLScannerDelegate: AnyObject {

	/// Called on each start tag (including self-closing).
	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool)

	/// Called on each end tag.
	func htmlScanner(_ scanner: HTMLScanner,
	                 didEndTag name: ArraySlice<UInt8>)

	/// Called for each run of character content (entity references expanded).
	func htmlScanner(_ scanner: HTMLScanner,
	                 didFindCharacters bytes: ArraySlice<UInt8>)

	/// Called once when parsing reaches end of document.
	func htmlScannerDidEnd(_ scanner: HTMLScanner)
}

public extension HTMLScannerDelegate {

	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool) {}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didEndTag name: ArraySlice<UInt8>) {}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didFindCharacters bytes: ArraySlice<UInt8>) {}

	func htmlScannerDidEnd(_ scanner: HTMLScanner) {}
}
