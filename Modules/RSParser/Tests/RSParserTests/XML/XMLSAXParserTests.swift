//
//  XMLSAXParserTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/18/26.
//

import Testing
@testable import RSParser

@Suite struct XMLSAXParserTests {

	// MARK: - Basic structure

	@Test func singleElement() {
		let events = parse("<root/>")
		#expect(events == [
			.start("root", prefix: nil, uri: nil, attributes: [:]),
			.end("root", prefix: nil, uri: nil),
			.done
		])
	}

	@Test func elementWithContent() {
		let events = parse("<root>hello</root>")
		#expect(events == [
			.start("root", prefix: nil, uri: nil, attributes: [:]),
			.characters("hello"),
			.end("root", prefix: nil, uri: nil),
			.done
		])
	}

	@Test func nestedElements() {
		let events = parse("<a><b>x</b><c/></a>")
		#expect(events == [
			.start("a", prefix: nil, uri: nil, attributes: [:]),
			.start("b", prefix: nil, uri: nil, attributes: [:]),
			.characters("x"),
			.end("b", prefix: nil, uri: nil),
			.start("c", prefix: nil, uri: nil, attributes: [:]),
			.end("c", prefix: nil, uri: nil),
			.end("a", prefix: nil, uri: nil),
			.done
		])
	}

	@Test func attributes() {
		let events = parse("<a href=\"http://example.com\" title='X'/>")
		#expect(events == [
			.start("a", prefix: nil, uri: nil, attributes: ["href": "http://example.com", "title": "X"]),
			.end("a", prefix: nil, uri: nil),
			.done
		])
	}

	// MARK: - Namespaces

	@Test func namespacesResolveURI() {
		let xml = "<a xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>foo</dc:title></a>"
		let events = parse(xml)
		#expect(events.count == 6) // start a, start dc:title, chars, end dc:title, end a, done
		guard case let .start(name, prefix, uri, _) = events[1] else {
			Issue.record("expected start event for dc:title")
			return
		}
		#expect(name == "title")
		#expect(prefix == "dc")
		#expect(uri == "http://purl.org/dc/elements/1.1/")
	}

	@Test func defaultNamespace() {
		let xml = "<root xmlns=\"http://example.com/ns\"><child/></root>"
		let events = parse(xml)
		guard case let .start(name, prefix, uri, _) = events[1] else {
			Issue.record("expected start event")
			return
		}
		#expect(name == "child")
		#expect(prefix == nil)
		#expect(uri == "http://example.com/ns")
	}

	@Test func builtInXMLPrefix() {
		// xml:lang and xml:base don't require an xmlns declaration.
		let xml = "<a xml:lang=\"en\"><b xml:base=\"http://x.com\"/></a>"
		let events = parse(xml)
		if case let .start(_, _, _, attributes) = events[0] {
			#expect(attributes["xml:lang"] == "en")
		}
	}

	@Test func namespacePrefixInheritedFromOuterScope() {
		let xml = "<a xmlns:x=\"http://x.com\"><b><x:tag>ok</x:tag></b></a>"
		let events = parse(xml)
		let xTagStart = events.first(where: {
			if case let .start(name, _, _, _) = $0, name == "tag" { return true }
			return false
		})
		guard case let .start(_, prefix, uri, _) = xTagStart! else {
			Issue.record("expected to find x:tag start")
			return
		}
		#expect(prefix == "x")
		#expect(uri == "http://x.com")
	}

	@Test func xmlnsAttributeNotExposed() {
		// xmlns="..." should never appear in the attributes dictionary.
		let xml = "<a xmlns=\"foo\" href=\"http://x\"/>"
		let events = parse(xml)
		if case let .start(_, _, _, attributes) = events[0] {
			#expect(attributes == ["href": "http://x"])
		}
	}

	// MARK: - Entities

	@Test func xmlFiveEntitiesInContent() {
		let events = parse("<a>&amp;&lt;&gt;&quot;&apos;</a>")
		#expect(events[1] == .characters("&<>\"'"))
	}

	@Test func numericDecimalEntity() {
		let events = parse("<a>&#8212;</a>") // em dash
		#expect(events[1] == .characters("—"))
	}

	@Test func numericHexEntity() {
		let events = parse("<a>&#x2014;</a>")
		#expect(events[1] == .characters("—"))
	}

	@Test func numericHexEntityUppercaseX() {
		let events = parse("<a>&#X2014;</a>")
		#expect(events[1] == .characters("—"))
	}

	@Test func htmlNamedEntitiesPassThroughLiterally() {
		// XML mode (libxml2-compatible, no DTD) leaves unknown named entities literal.
		let events = parse("<a>&nbsp;&copy;&mdash;</a>")
		#expect(events[1] == .characters("&nbsp;&copy;&mdash;"))
	}

	@Test func unknownEntityPassesThroughLiterally() {
		let events = parse("<a>&foo;&bar</a>")
		#expect(events[1] == .characters("&foo;&bar"))
	}

	@Test func entitiesInAttributes() {
		let events = parse("<a href=\"x&amp;y\"/>")
		if case let .start(_, _, _, attributes) = events[0] {
			#expect(attributes["href"] == "x&y")
		}
	}

	// MARK: - CDATA

	@Test func cdataPassesThroughVerbatim() {
		// Inside CDATA, no entities are substituted — matches libxml2 behavior.
		let events = parse("<a><![CDATA[&amp;<b>&nbsp;</b>]]></a>")
		#expect(events[1] == .characters("&amp;<b>&nbsp;</b>"))
	}

	@Test func cdataWithClosingBrackets() {
		// A single `]` or `]]` inside CDATA is fine.
		let events = parse("<a><![CDATA[array[0] and [1]]==]]></a>")
		#expect(events[1] == .characters("array[0] and [1]]=="))
	}

	@Test func cdataWithNumericEntityLeavesLiteral() {
		// CDATA is raw — numeric entities pass through unchanged.
		let events = parse("<a><![CDATA[&#8212;]]></a>")
		#expect(events[1] == .characters("&#8212;"))
	}

	// MARK: - Liberal mode

	@Test func unescapedAmpersand() {
		let events = parse("<a>Fish & Chips</a>")
		#expect(events[1] == .characters("Fish & Chips"))
	}

	@Test func strayLessThan() {
		// `<` followed by non-name — liberal: emit as literal.
		let events = parse("<a>a < b</a>")
		let content = combineCharacters(events)
		#expect(content.contains("<"))
		#expect(content.contains("a "))
		#expect(content.contains("b"))
	}

	@Test func unclosedTagImpliesEndAtEOF() {
		let events = parse("<a><b>hello")
		let hasEndA = events.contains { e in
			if case .end(let name, _, _) = e, name == "a" { return true }
			return false
		}
		let hasEndB = events.contains { e in
			if case .end(let name, _, _) = e, name == "b" { return true }
			return false
		}
		#expect(hasEndA)
		#expect(hasEndB)
	}

	@Test func mismatchedEndTag() {
		// <a><b></a></b> — the scanner should recover.
		let events = parse("<a><b></a></b>")
		let ends = events.filter { if case .end = $0 { return true } else { return false } }
		#expect(ends.count >= 2)
	}

	// MARK: - Comments, PIs, DOCTYPE

	@Test func commentIsIgnored() {
		let events = parse("<a><!-- ignore me --><b/></a>")
		let names = events.compactMap { e -> String? in
			if case let .start(name, _, _, _) = e { return name }
			return nil
		}
		#expect(names == ["a", "b"])
	}

	@Test func processingInstructionIsIgnored() {
		let events = parse("<a><?target data?><b/></a>")
		let names = events.compactMap { e -> String? in
			if case let .start(name, _, _, _) = e { return name }
			return nil
		}
		#expect(names == ["a", "b"])
	}

	@Test func doctypeIsIgnored() {
		let xml = """
		<!DOCTYPE html [
		<!ENTITY foo "bar">
		]>
		<a/>
		"""
		let events = parse(xml)
		let starts = events.filter { if case .start = $0 { return true } else { return false } }
		#expect(starts.count == 1)
	}

	@Test func xmlDeclarationIsIgnored() {
		let events = parse("<?xml version=\"1.0\" encoding=\"UTF-8\"?><a/>")
		let starts = events.filter { if case .start = $0 { return true } else { return false } }
		#expect(starts.count == 1)
	}

	// MARK: - Encodings

	@Test func utf8BOM() {
		let xml = [0xEF, 0xBB, 0xBF].map(UInt8.init) + Array("<a>hello</a>".utf8)
		let events = parseBytes(xml)
		#expect(events[1] == .characters("hello"))
	}

	@Test func utf16LEBOM() {
		var bytes: [UInt8] = [0xFF, 0xFE]
		for scalar in "<a>hello</a>".unicodeScalars {
			let v = UInt16(scalar.value)
			bytes.append(UInt8(v & 0xFF))
			bytes.append(UInt8(v >> 8))
		}
		let events = parseBytes(bytes)
		#expect(events[1] == .characters("hello"))
	}

	@Test func utf16BEBOM() {
		var bytes: [UInt8] = [0xFE, 0xFF]
		for scalar in "<a>hello</a>".unicodeScalars {
			let v = UInt16(scalar.value)
			bytes.append(UInt8(v >> 8))
			bytes.append(UInt8(v & 0xFF))
		}
		let events = parseBytes(bytes)
		#expect(events[1] == .characters("hello"))
	}

	@Test func latin1Declaration() {
		// café encoded in ISO-8859-1.
		let bytes: [UInt8] =
			Array("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a>caf".utf8)
			+ [0xE9]
			+ Array("</a>".utf8)
		let events = parseBytes(bytes)
		#expect(events[1] == .characters("café"))
	}

	@Test func windows1252Declaration() {
		let bytes: [UInt8] =
			Array("<?xml version=\"1.0\" encoding=\"windows-1252\"?><a>".utf8)
			+ [0x93] + Array("Hi".utf8) + [0x94]
			+ Array("</a>".utf8)
		let events = parseBytes(bytes)
		#expect(events[1] == .characters("\u{201C}Hi\u{201D}"))
	}

	// MARK: - beginStoringCharacters / currentString

	@Test func beginStoringCharacters() {
		let delegate = TestDelegate()
		delegate.onStart = { parser, name, _, _, _ in
			if name == "title" {
				parser.beginStoringCharacters()
			}
		}
		delegate.onEnd = { parser, name, _, _ in
			if name == "title" {
				delegate.accumulated = parser.currentStringWithTrimmedWhitespace
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array("<root><title>  Hello  </title></root>".utf8))
		#expect(delegate.accumulated == "Hello")
	}

	// MARK: - Raw inner content capture

	@Test func captureRawInnerContent() {
		let xml = #"<root><content type="xhtml"><div>hello <em>world</em>!</div></content></root>"#
		let delegate = TestDelegate()
		delegate.onStart = { parser, name, _, _, attributes in
			if name == "content" && attributes["type"] == "xhtml" {
				parser.captureRawInnerContent()
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array(xml.utf8))
		let starts = delegate.events.compactMap { e -> String? in
			if case let .start(name, _, _, _) = e { return name }
			return nil
		}
		#expect(starts == ["root", "content"])
		#expect(delegate.captured == "<div>hello <em>world</em>!</div>")
	}

	@Test func captureRawInnerContentWithNestedSameName() {
		let xml = "<root><a><a>x</a>y<a>z</a></a></root>"
		let delegate = TestDelegate()
		delegate.onStart = { parser, name, _, _, _ in
			if name == "a" && delegate.captured == nil {
				parser.captureRawInnerContent()
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array(xml.utf8))
		#expect(delegate.captured == "<a>x</a>y<a>z</a>")
	}

	@Test func captureRawInnerContentPreservesRawEntities() {
		// Raw bytes: &amp; stays as &amp; in the captured range — not expanded.
		let xml = "<root><body>a &amp; b &lt; c</body></root>"
		let delegate = TestDelegate()
		delegate.onStart = { parser, name, _, _, _ in
			if name == "body" {
				parser.captureRawInnerContent()
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array(xml.utf8))
		#expect(delegate.captured == "a &amp; b &lt; c")
	}

	@Test func captureRawInnerContentEmpty() {
		let xml = "<root><body></body></root>"
		let delegate = TestDelegate()
		delegate.onStart = { parser, name, _, _, _ in
			if name == "body" {
				parser.captureRawInnerContent()
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array(xml.utf8))
		#expect(delegate.captured == "")
	}

	// MARK: - XMLNamespace conveniences

	@Test func namespaceConvenienceIsDublinCore() {
		let xml = """
		<rss xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:creator>Ana</dc:creator></rss>
		"""
		let delegate = TestDelegate()
		var sawDublinCore = false
		delegate.onStart = { _, name, _, _, _ in
			if name == "creator" {
				sawDublinCore = delegate.lastStartNamespace?.isDublinCore ?? false
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array(xml.utf8))
		#expect(sawDublinCore)
	}

	@Test func namespaceConvenienceIsAtom() {
		let xml = "<feed xmlns=\"http://www.w3.org/2005/Atom\"><entry/></feed>"
		let delegate = TestDelegate()
		var atomCount = 0
		delegate.onStart = { _, _, _, _, _ in
			if delegate.lastStartNamespace?.isAtom == true {
				atomCount += 1
			}
		}
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(Array(xml.utf8))
		#expect(atomCount == 2) // feed + entry
	}

	// MARK: - Self-closing

	@Test func selfClosingFiresEndEvent() {
		let events = parse("<a/>")
		let ends = events.filter { if case .end = $0 { return true } else { return false } }
		#expect(ends.count == 1)
	}

	// MARK: - Helpers

	private func parse(_ xml: String) -> [Event] {
		parseBytes(Array(xml.utf8))
	}

	private func parseBytes(_ bytes: [UInt8]) -> [Event] {
		let delegate = TestDelegate()
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(bytes)
		return delegate.events
	}

	private func combineCharacters(_ events: [Event]) -> String {
		var s = ""
		for e in events {
			if case let .characters(text) = e {
				s += text
			}
		}
		return s
	}
}

// MARK: - Event model

enum Event: Equatable {
	case start(String, prefix: String?, uri: String?, attributes: [String: String])
	case end(String, prefix: String?, uri: String?)
	case characters(String)
	case done
}

private final class TestDelegate: XMLSAXParserDelegate {

	var events: [Event] = []
	var onStart: ((XMLSAXParser, String, String?, String?, [String: String]) -> Void)?
	var onEnd: ((XMLSAXParser, String, String?, String?) -> Void)?
	var accumulated: String?
	var lastStartNamespace: XMLNamespace?
	var captured: String?

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didStartElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace,
	                  attributes: XMLAttributes) {
		let nameStr = String(decoding: localName, as: UTF8.self)
		let dict = attributes.dictionary()
		events.append(.start(nameStr, prefix: namespace.prefix, uri: namespace.uri, attributes: dict))
		lastStartNamespace = namespace
		onStart?(parser, nameStr, namespace.prefix, namespace.uri, dict)
	}

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didEndElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {
		let nameStr = String(decoding: localName, as: UTF8.self)
		events.append(.end(nameStr, prefix: namespace.prefix, uri: namespace.uri))
		onEnd?(parser, nameStr, namespace.prefix, namespace.uri)
	}

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didCaptureRawInnerContent bytes: ArraySlice<UInt8>,
	                  forElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {
		captured = String(decoding: bytes, as: UTF8.self)
	}

	func xmlSAXParser(_ parser: XMLSAXParser, didFindCharacters bytes: ArraySlice<UInt8>) {
		let s = String(decoding: bytes, as: UTF8.self)
		// Collapse adjacent character events for simpler test assertions.
		if case .characters(let last) = events.last ?? .done {
			events[events.count - 1] = .characters(last + s)
		} else {
			events.append(.characters(s))
		}
	}

	func xmlSAXParserDidEnd(_ parser: XMLSAXParser) {
		events.append(.done)
	}
}
