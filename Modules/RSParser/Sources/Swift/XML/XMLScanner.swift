//
//  XMLScanner.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

// Low-level byte-oriented scanner for XML events.
//
// Feeds the parser with one event at a time. Liberal: never throws for bad
// input, recovers as best it can, and passes garbage through as literal text.
//
// The scanner doesn't know about namespace resolution — it surfaces raw
// (prefix, localName) byte ranges and lets the parser layer resolve URIs.

struct XMLScanner {

	/// An event emitted by the scanner. Byte ranges point into the input buffer.
	/// Attributes surface with raw byte ranges only — the parser resolves namespaces.
	enum Event {
		case startElement(prefix: Range<Int>?, localName: Range<Int>, attributes: [RawAttribute], selfClosing: Bool)
		case endElement(prefix: Range<Int>?, localName: Range<Int>)
		case characters([UInt8])   // entity-expanded bytes
		case endOfDocument
	}

	/// Raw attribute data as produced by the scanner. The parser turns each of these
	/// into an `XMLAttributes.Attribute` after resolving the prefix to a URI.
	///
	/// Byte fields are `ArraySlice<UInt8>` — by default they view into the scanner's
	/// input buffer (no copy). When entity expansion produces bytes that differ from
	/// the input (e.g. `&amp;` → `&`), the slice wraps a fresh owned `[UInt8]`.
	struct RawAttribute {
		let prefixSlice: ArraySlice<UInt8>?
		let localNameSlice: ArraySlice<UInt8>
		let valueSlice: ArraySlice<UInt8>
	}

	private let input: [UInt8]
	private var pos: Int = 0

	init(_ input: [UInt8]) {
		self.input = input
	}

	/// Current byte offset into the input. After `next()` returns, this is the position
	/// just past the last event's bytes. Before calling `next()`, this is where the
	/// next event will start scanning from — useful for capturing byte ranges that
	/// span multiple events (e.g. raw-inner-content capture).
	var position: Int {
		pos
	}

	// MARK: - Entry point

	/// Advance and return the next event, or .endOfDocument.
	mutating func next() -> Event {
		while pos < input.count {
			let b = input[pos]

			if b == .asciiLessThan {
				if let event = scanMarkup() {
					return event
				}
				// scanMarkup returned nil — it consumed a comment/PI/DOCTYPE silently,
				// keep scanning for the next event.
				continue
			}

			// Character content.
			return scanCharacters()
		}
		return .endOfDocument
	}
}

// MARK: - Private

private extension XMLScanner {

	// MARK: - Markup dispatch

	/// Handle everything starting with `<`. Returns nil for silently-consumed markup
	/// (comments, PIs, DOCTYPE, CDATA that produced no output).
	mutating func scanMarkup() -> Event? {
		assert(input[pos] == .asciiLessThan)
		let next = peek(1)

		// `<!` — comment, CDATA, or DOCTYPE
		if next == .asciiExclamation {
			if matchPrefix("<!--") {
				consumeComment()
				return nil
			}
			if matchPrefix("<![CDATA[") {
				return scanCDATA()
			}
			if matchPrefix("<!DOCTYPE") || matchPrefix("<!doctype") {
				consumeDOCTYPE()
				return nil
			}
			// Unknown declaration — skip to `>`.
			consumeUnknownDeclaration()
			return nil
		}

		// `<?xml...?>` processing instruction (already-handled XML decl case too)
		if next == .asciiQuestion {
			consumeProcessingInstruction()
			return nil
		}

		// `</` end tag
		if next == .asciiSlash {
			return scanEndTag()
		}

		// Regular start tag.
		if next?.isXMLNameStart == true {
			return scanStartTag()
		}

		// Stray `<` — emit it as literal text and advance.
		pos += 1
		return .characters([.asciiLessThan])
	}

	// MARK: - Start tag

	mutating func scanStartTag() -> Event {
		assert(input[pos] == .asciiLessThan)
		pos += 1 // consume `<`

		let (prefix, local) = scanQualifiedName()

		var attributes = [RawAttribute]()
		var selfClosing = false

		// Attribute loop.
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
				// Self-closing `/>`
				if peek(1) == .asciiGreaterThan {
					selfClosing = true
					pos += 2
					break
				}
				// Stray `/`. Eat it, keep going (liberal).
				pos += 1
				continue
			}
			if !b.isXMLNameStart {
				// Unrecognized garbage — advance and try again.
				pos += 1
				continue
			}
			if let attribute = scanAttribute() {
				attributes.append(attribute)
			}
		}

		return .startElement(prefix: prefix, localName: local, attributes: attributes, selfClosing: selfClosing)
	}

	mutating func scanAttribute() -> RawAttribute? {
		let (prefix, local) = scanQualifiedName()
		let prefixSlice: ArraySlice<UInt8>? = prefix.map { input[$0] }
		let localSlice = input[local]

		skipWhitespace()
		// Expect `=`. Liberal: if missing, treat as empty value.
		guard pos < input.count, input[pos] == .asciiEquals else {
			return RawAttribute(prefixSlice: prefixSlice, localNameSlice: localSlice, valueSlice: ArraySlice())
		}
		pos += 1
		skipWhitespace()

		guard pos < input.count else {
			return RawAttribute(prefixSlice: prefixSlice, localNameSlice: localSlice, valueSlice: ArraySlice())
		}

		let valueSlice = scanAttributeValue()
		return RawAttribute(prefixSlice: prefixSlice, localNameSlice: localSlice, valueSlice: valueSlice)
	}

	mutating func scanAttributeValue() -> ArraySlice<UInt8> {
		guard pos < input.count else {
			return ArraySlice()
		}
		let quote = input[pos]
		if quote == .asciiDoubleQuote || quote == .asciiSingleQuote {
			pos += 1
			let start = pos
			var out = [UInt8]()
			var expanded = false
			while pos < input.count {
				let b = input[pos]
				if b == quote {
					// Fast path: no entities — return a view into the input buffer.
					if !expanded {
						let slice = input[start..<pos]
						pos += 1
						return slice
					}
					pos += 1
					return out[...]
				}
				if b == .asciiAmpersand {
					if !expanded {
						// Transition to slow path: copy what we've seen so far into an owned buffer.
						out.reserveCapacity(32)
						out.append(contentsOf: input[start..<pos])
						expanded = true
					}
					let result = XMLEntities.decode(bytes: input, at: pos, mode: .normal)
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
				return input[start..<pos]
			}
			return out[...]
		}

		// Unquoted — consume until whitespace, `>`, or `/`. Liberal.
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
				let result = XMLEntities.decode(bytes: input, at: pos, mode: .normal)
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
			return input[start..<pos]
		}
		return out[...]
	}

	// MARK: - End tag

	mutating func scanEndTag() -> Event {
		assert(input[pos] == .asciiLessThan && peek(1) == .asciiSlash)
		pos += 2

		let (prefix, local) = scanQualifiedName()

		// Skip to `>` (liberal: tolerate whitespace and garbage).
		while pos < input.count && input[pos] != .asciiGreaterThan {
			pos += 1
		}
		if pos < input.count {
			pos += 1
		}

		return .endElement(prefix: prefix, localName: local)
	}

	// MARK: - CDATA

	mutating func scanCDATA() -> Event {
		// `<![CDATA[` — already matched but not consumed.
		pos += 9
		let start = pos
		// Scan to `]]>`.
		var end = pos
		while end + 2 < input.count {
			if input[end] == .asciiRightBracket
				&& input[end + 1] == .asciiRightBracket
				&& input[end + 2] == .asciiGreaterThan {
				break
			}
			end += 1
		}
		// If we didn't find `]]>` before EOF, consume to end of buffer (liberal).
		if end + 2 >= input.count {
			end = input.count
			pos = end
		} else {
			pos = end + 3
		}

		// Per our liberal mode: inside CDATA, preserve the predefined XML entities
		// (&amp; &lt; &gt; &quot; &apos;) but still expand numeric and HTML named entities.
		let bytes = Array(input[start..<end])
		let expanded = expandEntitiesPreservingPredefinedXML(bytes)
		return .characters(expanded)
	}

	func expandEntitiesPreservingPredefinedXML(_ bytes: [UInt8]) -> [UInt8] {
		// Quick check: if no `&`, return as-is.
		if !bytes.contains(.asciiAmpersand) {
			return bytes
		}
		var out = [UInt8]()
		out.reserveCapacity(bytes.count)
		var i = 0
		while i < bytes.count {
			let b = bytes[i]
			if b == .asciiAmpersand {
				let result = XMLEntities.decode(bytes: bytes, at: i, mode: .preservePredefinedXML)
				out.append(contentsOf: result.bytes)
				i = result.nextIndex
			} else {
				out.append(b)
				i += 1
			}
		}
		return out
	}

	// MARK: - Consumption of non-emitting markup

	mutating func consumeComment() {
		// Caller already matched `<!--` but didn't advance past it.
		pos += 4
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

	mutating func consumeProcessingInstruction() {
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

	mutating func consumeDOCTYPE() {
		pos += 9 // `<!DOCTYPE`
		// The DOCTYPE may have an internal subset `[...]` before its closing `>`.
		var depth = 0
		while pos < input.count {
			let b = input[pos]
			if b == .asciiLeftBracket {
				depth += 1
			} else if b == .asciiRightBracket {
				if depth > 0 {
					depth -= 1
				}
			} else if b == .asciiGreaterThan && depth == 0 {
				pos += 1
				return
			}
			pos += 1
		}
	}

	mutating func consumeUnknownDeclaration() {
		// Skip to `>`.
		while pos < input.count {
			if input[pos] == .asciiGreaterThan {
				pos += 1
				return
			}
			pos += 1
		}
	}

	// MARK: - Character data

	mutating func scanCharacters() -> Event {
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
					// Copy the fast-path so far and switch to the slow path.
					out.reserveCapacity(input.count - start)
					out.append(contentsOf: input[start..<pos])
					sawEntity = true
				}
				let result = XMLEntities.decode(bytes: input, at: pos, mode: .normal)
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
			return .characters(Array(input[start..<pos]))
		}
		return .characters(out)
	}

	// MARK: - Name scanning

	/// Scan an XML name at the current position, splitting on colon.
	/// Advances `pos` past the name. Returns byte ranges into `input`.
	/// If no name is present, returns empty ranges at the current position.
	mutating func scanQualifiedName() -> (prefix: Range<Int>?, localName: Range<Int>) {
		let start = pos
		while pos < input.count && input[pos].isXMLNameChar {
			pos += 1
		}
		let end = pos
		// Look for a colon splitting prefix and local name.
		for i in start..<end {
			if input[i] == .asciiColon {
				return (start..<i, (i + 1)..<end)
			}
		}
		return (nil, start..<end)
	}

	// MARK: - Utilities

	func peek(_ offset: Int) -> UInt8? {
		let i = pos + offset
		guard i < input.count else {
			return nil
		}
		return input[i]
	}

	mutating func skipWhitespace() {
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
}
