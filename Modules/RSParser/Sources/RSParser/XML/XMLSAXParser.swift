//
//  XMLSAXParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

// Pure-Swift, liberal, byte-oriented XML parser with a SAX-style delegate API.
//
// Replaces RSSAXParser (libxml2-backed). Operates on `[UInt8]` or `Data` given
// up front — no streaming. Decodes non-UTF-8 encodings to UTF-8 first, then
// scans the buffer in a single pass.
//
// Usage:
//   let parser = XMLSAXParser(delegate: myDelegate)
//   parser.parse(data)
//
// Thread-safe in the trivial sense: each instance is single-threaded. Not
// re-entrant. Callbacks happen on the calling thread.

public final class XMLSAXParser {

	public weak var delegate: XMLSAXParserDelegate?

	private var storingCharacters = false
	private var charactersBuffer: [UInt8] = []
	private var namespaceContext = XMLNamespaceContext()
	private var elementStack: [StackEntry] = []

	/// Set to true by `captureRawInnerContent()` when the delegate requests pass-through
	/// from inside `didStartElement`. Read and reset by the parser immediately after the
	/// didStartElement call returns.
	private var rawCaptureRequested = false

	fileprivate struct StackEntry {
		let namespace: XMLNamespace
		let localNameSlice: ArraySlice<UInt8>
	}

	public init(delegate: XMLSAXParserDelegate) {
		self.delegate = delegate
	}

	/// Request that the parser capture the raw inner bytes of the element that is
	/// currently being started, rather than dispatching child start/end/characters
	/// events. Must be called from within `didStartElement`. When the matching end tag
	/// is reached, the delegate receives `didCaptureRawInnerContent` with the captured
	/// bytes, followed by `didEndElement` for the outer element.
	///
	/// Useful for content that the consumer wants as a string verbatim, e.g. Atom
	/// `<content type="xhtml">`.
	public func captureRawInnerContent() {
		rawCaptureRequested = true
	}

	// MARK: - Public API

	public func parse(_ data: Data) {
		parse(Array(data))
	}

	public func parse(_ bytes: [UInt8]) {
		let utf8 = XMLEncoding.toUTF8(bytes)
		var scanner = XMLScanner(utf8)

		while true {
			let event = scanner.next()
			switch event {
			case .startElement(let prefixRange, let localRange, let rawAttributes, let selfClosing):
				// Capture innerStart *before* handleStart, in case pass-through is requested.
				// After scanner has emitted the start event, its position is just past `>`.
				let innerStart = scanner.position
				let passThrough = handleStart(utf8: utf8, prefixRange: prefixRange, localRange: localRange, rawAttributes: rawAttributes, selfClosing: selfClosing)
				if let passThrough, !selfClosing {
					runPassThrough(innerStart: innerStart,
					               outerNamespace: passThrough.namespace,
					               outerLocalSlice: passThrough.localSlice,
					               scanner: &scanner,
					               utf8: utf8)
				}
			case .endElement(let prefixRange, let localRange):
				handleEnd(utf8: utf8, prefixRange: prefixRange, localRange: localRange)
			case .characters(let bytes):
				handleCharacters(bytes)
			case .endOfDocument:
				// Close any remaining open elements (liberal).
				while !elementStack.isEmpty {
					let top = elementStack.removeLast()
					emitEndElement(entry: top)
				}
				delegate?.xmlSAXParserDidEnd(self)
				return
			}
		}
	}

	public func beginStoringCharacters() {
		storingCharacters = true
		charactersBuffer.removeAll(keepingCapacity: true)
		if charactersBuffer.capacity == 0 {
			charactersBuffer.reserveCapacity(1024)
		}
	}

	public func endStoringCharacters() {
		storingCharacters = false
		charactersBuffer.removeAll(keepingCapacity: true)
	}

	/// Returns the accumulated characters since `beginStoringCharacters` was called,
	/// or nil if we're not currently storing.
	public var currentCharacters: [UInt8]? {
		storingCharacters ? charactersBuffer : nil
	}

	public var currentStringWithTrimmedWhitespace: String? {
		guard storingCharacters, !charactersBuffer.isEmpty else {
			return nil
		}
		let trimmed = String(decoding: charactersBuffer, as: UTF8.self)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

// MARK: - Private

private extension XMLSAXParser {

	// MARK: - Event handling

	/// Info the parse loop needs to drive a pass-through capture after handleStart.
	struct PassThroughInfo {
		let namespace: XMLNamespace
		let localSlice: ArraySlice<UInt8>
	}

	/// Returns non-nil if the delegate requested raw-inner capture for this element.
	/// In that case, the caller is responsible for draining the scanner to the
	/// matching end tag. Namespace scope is pushed, but the element is NOT pushed
	/// onto `elementStack` — pass-through owns the end-tag handling.
	func handleStart(utf8: [UInt8],
	                 prefixRange: Range<Int>?,
	                 localRange: Range<Int>,
	                 rawAttributes: [XMLScanner.RawAttribute],
	                 selfClosing: Bool) -> PassThroughInfo? {
		// Pull xmlns bindings out of the raw attributes and push a new scope.
		let nsBindings = extractNamespaceBindings(rawAttributes: rawAttributes)
		namespaceContext.pushScope(bindings: nsBindings)

		// Resolve the element's namespace URI. Unprefixed elements inherit the default.
		let prefixString: String? = prefixRange.map { String(decoding: utf8[$0], as: UTF8.self) }
		let elementURI = namespaceContext.resolve(prefix: prefixString)
		let elementNamespace = XMLNamespace(prefix: prefixString, uri: elementURI)

		// Build the XMLAttributes (strip xmlns/xmlns:*).
		// Attributes follow the spec: unprefixed attributes have no namespace.
		// Fast path: element has no attributes at all — share the empty view and
		// skip the array allocation entirely. This hits for ~80% of elements in
		// a typical RSS feed (title, link, description, pubDate, etc.).
		let attributes: XMLAttributes
		if rawAttributes.isEmpty {
			attributes = .empty
		} else {
			var visibleAttributes = [XMLAttributes.Attribute]()
			visibleAttributes.reserveCapacity(rawAttributes.count)
			for raw in rawAttributes {
				if isXmlnsAttribute(raw) {
					continue
				}
				let attributePrefix: String? = raw.prefixSlice.map { String(decoding: $0, as: UTF8.self) }
				let attributeURI: String? = (attributePrefix == nil) ? nil : namespaceContext.resolve(prefix: attributePrefix)
				let attributeNamespace = XMLNamespace(prefix: attributePrefix, uri: attributeURI)
				visibleAttributes.append(XMLAttributes.Attribute(
					namespace: attributeNamespace,
					localNameSlice: raw.localNameSlice,
					valueSlice: raw.valueSlice
				))
			}
			attributes = visibleAttributes.isEmpty ? .empty : XMLAttributes(attributes: visibleAttributes)
		}

		let localSlice = utf8[localRange]

		// End any prior character accumulation (libxml clears on each new start-tag).
		endStoringCharacters()

		rawCaptureRequested = false
		delegate?.xmlSAXParser(self,
		                       didStartElement: localSlice,
		                       namespace: elementNamespace,
		                       attributes: attributes)
		let captureRequested = rawCaptureRequested
		rawCaptureRequested = false

		if captureRequested && !selfClosing {
			// Pass-through mode — don't push onto elementStack; the caller will drive
			// the scanner to the matching end tag, then emit didCaptureRawInnerContent
			// and didEndElement for this element.
			return PassThroughInfo(namespace: elementNamespace, localSlice: localSlice)
		}

		// Normal path. For self-closing elements with a capture request, we simply
		// skip the capture (inner content is empty) and proceed with the normal
		// start/end pair.
		let entry = StackEntry(
			namespace: elementNamespace,
			localNameSlice: localSlice
		)
		if selfClosing {
			emitEndElement(entry: entry)
		} else {
			elementStack.append(entry)
		}

		return nil
	}

	/// Drive the scanner forward, ignoring nested events, until we find the matching
	/// end tag for the pass-through element. Then emit `didCaptureRawInnerContent`
	/// with the byte range we captured, followed by `didEndElement` for the outer.
	func runPassThrough(innerStart: Int,
	                    outerNamespace: XMLNamespace,
	                    outerLocalSlice: ArraySlice<UInt8>,
	                    scanner: inout XMLScanner,
	                    utf8: [UInt8]) {
		// Keep an optional byte-slice of the outer prefix for fast comparison against
		// nested events. Only compare when the local name matches (rare path).
		let outerPrefixBytes: [UInt8]? = outerNamespace.prefix.map { Array($0.utf8) }
		var depth = 0

		while true {
			let eventStart = scanner.position
			let event = scanner.next()
			switch event {
			case .startElement(let prefixRange, let localRange, _, let innerSelfClosing):
				if !innerSelfClosing && isSameName(prefixRange: prefixRange,
				                                   localRange: localRange,
				                                   utf8: utf8,
				                                   outerLocal: outerLocalSlice,
				                                   outerPrefixBytes: outerPrefixBytes) {
					depth += 1
				}

			case .endElement(let prefixRange, let localRange):
				if isSameName(prefixRange: prefixRange,
				              localRange: localRange,
				              utf8: utf8,
				              outerLocal: outerLocalSlice,
				              outerPrefixBytes: outerPrefixBytes) {
					if depth == 0 {
						// Matching outer end — capture [innerStart, eventStart).
						emitPassThroughEnd(utf8: utf8,
						                   captureRange: innerStart..<eventStart,
						                   outerNamespace: outerNamespace,
						                   outerLocalSlice: outerLocalSlice)
						return
					}
					depth -= 1
				}

			case .characters:
				break // swallow during pass-through; bytes are in the input buffer

			case .endOfDocument:
				// Unclosed outer — flush what we have and synthesize the end.
				emitPassThroughEnd(utf8: utf8,
				                   captureRange: innerStart..<utf8.count,
				                   outerNamespace: outerNamespace,
				                   outerLocalSlice: outerLocalSlice)
				return
			}
		}
	}

	func emitPassThroughEnd(utf8: [UInt8],
	                        captureRange: Range<Int>,
	                        outerNamespace: XMLNamespace,
	                        outerLocalSlice: ArraySlice<UInt8>) {
		delegate?.xmlSAXParser(self,
		                       didCaptureRawInnerContent: utf8[captureRange],
		                       forElement: outerLocalSlice,
		                       namespace: outerNamespace)
		delegate?.xmlSAXParser(self,
		                       didEndElement: outerLocalSlice,
		                       namespace: outerNamespace)
		endStoringCharacters()
		namespaceContext.popScope()
	}

	/// Check whether an event's (prefix, local) matches the outer element's name.
	/// Compares local name first (fast fail), then prefix.
	func isSameName(prefixRange: Range<Int>?,
	                localRange: Range<Int>,
	                utf8: [UInt8],
	                outerLocal: ArraySlice<UInt8>,
	                outerPrefixBytes: [UInt8]?) -> Bool {
		let innerLocal = utf8[localRange]
		if !bytesEqual(innerLocal, outerLocal) {
			return false
		}
		// Local name matches — compare prefixes.
		if let prefixRange {
			guard let outerPrefixBytes else {
				return false
			}
			return bytesEqual(utf8[prefixRange], outerPrefixBytes[...])
		}
		return outerPrefixBytes == nil
	}

	func handleEnd(utf8: [UInt8], prefixRange: Range<Int>?, localRange: Range<Int>) {
		let incomingPrefix: String? = prefixRange.map { String(decoding: utf8[$0], as: UTF8.self) }
		let incomingLocal = utf8[localRange]

		// Find matching open element (scan from top).
		var matchIndex: Int? = nil
		for i in elementStack.indices.reversed() {
			let entry = elementStack[i]
			if entry.namespace.prefix == incomingPrefix && bytesEqual(entry.localNameSlice, incomingLocal) {
				matchIndex = i
				break
			}
		}

		if let matchIndex {
			// Pop intervening (emit their end events too).
			while elementStack.count > matchIndex + 1 {
				let top = elementStack.removeLast()
				emitEndElement(entry: top)
			}
			let matched = elementStack.removeLast()
			emitEndElement(entry: matched)
		} else {
			// No match — orphan end tag. Emit what we can.
			let uri = namespaceContext.resolve(prefix: incomingPrefix)
			let ns = XMLNamespace(prefix: incomingPrefix, uri: uri)
			endStoringCharacters()
			delegate?.xmlSAXParser(self,
			                       didEndElement: incomingLocal,
			                       namespace: ns)
			// No scope was pushed for this phantom, so nothing to pop.
		}
	}

	func emitEndElement(entry: StackEntry) {
		delegate?.xmlSAXParser(self,
		                       didEndElement: entry.localNameSlice,
		                       namespace: entry.namespace)
		endStoringCharacters()
		namespaceContext.popScope()
	}

	func handleCharacters(_ bytes: [UInt8]) {
		guard !bytes.isEmpty else {
			return
		}
		if storingCharacters {
			charactersBuffer.append(contentsOf: bytes)
		}
		delegate?.xmlSAXParser(self, didFindCharacters: bytes[...])
	}

	// MARK: - xmlns handling

	func extractNamespaceBindings(rawAttributes: [XMLScanner.RawAttribute]) -> [(prefix: String?, uri: String)] {
		var bindings = [(prefix: String?, uri: String)]()
		for attribute in rawAttributes {
			if attribute.prefixSlice == nil {
				// xmlns="..." → default namespace binding
				if bytesEqual(attribute.localNameSlice, xmlnsBytes[...]) {
					let uri = String(decoding: attribute.valueSlice, as: UTF8.self)
					bindings.append((prefix: nil, uri: uri))
				}
				continue
			}
			// xmlns:prefix="..."
			if let prefixSlice = attribute.prefixSlice, bytesEqual(prefixSlice, xmlnsBytes[...]) {
				let prefix = String(decoding: attribute.localNameSlice, as: UTF8.self)
				let uri = String(decoding: attribute.valueSlice, as: UTF8.self)
				bindings.append((prefix: prefix, uri: uri))
			}
		}
		return bindings
	}

	func isXmlnsAttribute(_ attribute: XMLScanner.RawAttribute) -> Bool {
		if let prefix = attribute.prefixSlice {
			// `xmlns:foo="…"` — prefix itself is "xmlns".
			return bytesEqual(prefix, xmlnsBytes[...])
		}
		// `xmlns="…"` — local name is "xmlns".
		return bytesEqual(attribute.localNameSlice, xmlnsBytes[...])
	}
}

/// Byte-equality for two `ArraySlice<UInt8>` views.
@inline(__always)
private func bytesEqual(_ a: ArraySlice<UInt8>, _ b: ArraySlice<UInt8>) -> Bool {
	guard a.count == b.count else {
		return false
	}
	var ai = a.startIndex
	var bi = b.startIndex
	while ai != a.endIndex {
		if a[ai] != b[bi] {
			return false
		}
		ai += 1
		bi += 1
	}
	return true
}

private let xmlnsBytes: [UInt8] = Array("xmlns".utf8)
